// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {AllocationRouter} from "src/factory/AllocationRouter.sol";
import {VaultFactory} from "src/factory/VaultFactory.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockSwapper} from "test/mocks/MockSwapper.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringVault} from "src/base/BoringVault.sol";

contract AllocationRouterTest is Test {
    VaultFactory factory;
    MockERC20 base;
    MockERC20 asset1;
    MockERC20 asset2;
    MockSwapper swapper;

    function setUp() external {
        factory = new VaultFactory();
        base = new MockERC20("Base", "BASE", 18);
        asset1 = new MockERC20("Asset1", "A1", 18);
        asset2 = new MockERC20("Asset2", "A2", 18);
        swapper = new MockSwapper();
        base.mint(address(this), 100 ether);
    }

    function testDepositAndRebalance() external {
        BoringVault vault;
        TellerWithMultiAssetSupport teller;
        {
            address balancer = address(0);
            address payout = address(0x1234);
            MockERC20[] memory assets = new MockERC20[](2);
            assets[0] = asset1;
            assets[1] = asset2;
            bool[] memory pegged = new bool[](2);
            pegged[0] = true;
            pegged[1] = true;
            address[] memory providers = new address[](2);
            providers[0] = address(0);
            providers[1] = address(0);
            (address v, , address t, , ) = factory.createVault(
                "MyVault",
                "MV",
                base,
                balancer,
                payout,
                assets,
                pegged,
                providers
            );
            vault = BoringVault(v);
            teller = TellerWithMultiAssetSupport(t);
        }

        AllocationRouter.Allocation[] memory allocs = new AllocationRouter.Allocation[](2);
        allocs[0] = AllocationRouter.Allocation({asset: asset1, bps: 5000});
        allocs[1] = AllocationRouter.Allocation({asset: asset2, bps: 5000});
        AllocationRouter router = new AllocationRouter(address(this), swapper, teller, base, allocs);

        base.approve(address(router), 10 ether);
        uint256 shares = router.deposit(10 ether, 0);
        assertEq(shares, 10 ether);
    }
}
