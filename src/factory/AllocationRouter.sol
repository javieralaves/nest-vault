// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ISwapper} from "../interfaces/ISwapper.sol";
import {TellerWithMultiAssetSupport} from "../base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringVault} from "../base/BoringVault.sol";

contract AllocationRouter is Auth {
    struct Allocation {
        ERC20 asset;
        uint16 bps;
    }

    ISwapper public immutable swapper;
    TellerWithMultiAssetSupport public immutable teller;
    ERC20 public immutable baseAsset;

    Allocation[] public allocations;

    event AllocationsUpdated();
    event DepositRouted(address indexed user, uint256 amountIn, uint256 sharesOut);

    constructor(
        address owner,
        ISwapper _swapper,
        TellerWithMultiAssetSupport _teller,
        ERC20 _baseAsset,
        Allocation[] memory initialAllocations
    ) Auth(owner, Authority(address(0))) {
        swapper = _swapper;
        teller = _teller;
        baseAsset = _baseAsset;
        _setAllocations(initialAllocations);
    }

    function setAllocations(Allocation[] calldata newAllocs) external requiresAuth {
        _setAllocations(newAllocs);
    }

    function _setAllocations(Allocation[] memory newAllocs) internal {
        delete allocations;
        uint256 total;
        uint256 len = newAllocs.length;
        for (uint256 i; i < len; ++i) {
            allocations.push(newAllocs[i]);
            total += newAllocs[i].bps;
        }
        require(total == 1e4, "bad-bps");
        emit AllocationsUpdated();
    }

    function deposit(uint256 amount, uint256 minShares) external returns (uint256 sharesOut) {
        baseAsset.transferFrom(msg.sender, address(this), amount);
        sharesOut = _allocate(amount);
        require(sharesOut >= minShares, "min-shares");
        BoringVault(address(teller.vault())).transfer(msg.sender, sharesOut);
        emit DepositRouted(msg.sender, amount, sharesOut);
    }

    function _allocate(uint256 amount) internal returns (uint256 sharesOut) {
        uint256 len = allocations.length;
        for (uint256 i; i < len; ++i) {
            Allocation memory al = allocations[i];
            uint256 portion = amount * al.bps / 1e4;
            uint256 received;
            if (al.asset != baseAsset) {
                baseAsset.approve(address(swapper), portion);
                received = swapper.swap(baseAsset, al.asset, portion, address(this));
            } else {
                received = portion;
            }
            al.asset.approve(address(teller.vault()), received);
            sharesOut += teller.deposit(al.asset, received, 0);
        }
    }

    function rebalance() external requiresAuth {
        BoringVault vault = BoringVault(address(teller.vault()));
        uint256 len = allocations.length;
        uint256 total;
        for (uint256 i; i < len; ++i) {
            total += allocations[i].asset.balanceOf(address(vault));
        }
        for (uint256 i; i < len; ++i) {
            Allocation memory al = allocations[i];
            uint256 target = total * al.bps / 1e4;
            uint256 current = al.asset.balanceOf(address(vault));
            if (current > target) {
                uint256 excess = current - target;
                // approve swapper with tokens in vault
                address[] memory targets = new address[](2);
                bytes[] memory datas = new bytes[](2);
                uint256[] memory values = new uint256[](2);
                targets[0] = address(al.asset);
                datas[0] = abi.encodeWithSelector(ERC20.approve.selector, address(swapper), excess);
                targets[1] = address(swapper);
                datas[1] = abi.encodeWithSelector(ISwapper.swap.selector, al.asset, baseAsset, excess, address(vault));
                vault.manage(targets, datas, values);
            } else if (current < target) {
                uint256 deficit = target - current;
                address[] memory targets = new address[](2);
                bytes[] memory datas = new bytes[](2);
                uint256[] memory values = new uint256[](2);
                targets[0] = address(baseAsset);
                datas[0] = abi.encodeWithSelector(ERC20.approve.selector, address(swapper), deficit);
                targets[1] = address(swapper);
                datas[1] = abi.encodeWithSelector(ISwapper.swap.selector, baseAsset, al.asset, deficit, address(vault));
                vault.manage(targets, datas, values);
            }
        }
    }
}

