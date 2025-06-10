// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {VaultFactory} from "src/factory/VaultFactory.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringVault} from "src/base/BoringVault.sol";

contract VaultFactoryTest is Test {
    VaultFactory factory;
    MockERC20 base;
    MockERC20 asset;

    function setUp() external {
        factory = new VaultFactory();
        base = new MockERC20("Base", "BASE", 18);
        asset = new MockERC20("Asset", "ASSET", 18);
        base.mint(address(this), 10 ether);
        asset.mint(address(this), 5 ether);
    }

    function testCreateAndDeposit() external {
        BoringVault vault;
        TellerWithMultiAssetSupport teller;
        {
            address balancer = address(0);
            address payout = address(0x1234);
            MockERC20[] memory assets = new MockERC20[](1);
            assets[0] = asset;
            bool[] memory pegged = new bool[](1);
            pegged[0] = true;
            address[] memory providers = new address[](1);
            providers[0] = address(0);
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

        base.approve(address(vault), 10 ether);
        uint256 shares0 = teller.deposit(base, 10 ether, 0);
        assertEq(shares0, 10 ether);

        asset.approve(address(vault), 5 ether);
        uint256 shares1 = teller.deposit(asset, 5 ether, 0);
        assertEq(shares1, 5 ether);
    }
}
