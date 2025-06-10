// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BoringVault} from "../base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "../base/Roles/ManagerWithMerkleVerification.sol";
import {TellerWithMultiAssetSupport} from "../base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "../base/Roles/AccountantWithRateProviders.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import "../helper/Constants.sol";

/**
 * @title VaultFactory
 * @notice Allows anyone to deploy a minimal Boring Vault setup with custom assets.
 */
contract VaultFactory {
    event VaultCreated(address vault, address manager, address teller, address accountant, address authority);

    function createVault(
        string calldata name,
        string calldata symbol,
        ERC20 base,
        address balancerVault,
        address payout,
        ERC20[] calldata assets,
        bool[] calldata isPeggedToBase,
        address[] calldata rateProviders
    ) external returns (address vaultAddr, address managerAddr, address tellerAddr, address accountantAddr, address authorityAddr) {
        require(assets.length == isPeggedToBase.length && assets.length == rateProviders.length, "length mismatch");

        // Deploy core contracts owned by the caller
        BoringVault vault = new BoringVault(msg.sender, name, symbol, base.decimals());
        AccountantWithRateProviders accountant = new AccountantWithRateProviders(
            msg.sender,
            address(vault),
            payout,
            uint96(10 ** base.decimals()),
            address(base),
            1.001e4,
            0.999e4,
            3600,
            0
        );
        TellerWithMultiAssetSupport teller = new TellerWithMultiAssetSupport(msg.sender, address(vault), address(accountant));
        ManagerWithMerkleVerification manager = new ManagerWithMerkleVerification(msg.sender, address(vault), balancerVault);
        RolesAuthority authority = new RolesAuthority(msg.sender, Authority(address(0)));

        vault.setAuthority(authority);
        accountant.setAuthority(authority);
        teller.setAuthority(authority);
        manager.setAuthority(authority);

        // Configure role capabilities
        authority.setRoleCapability(MANAGER_ROLE, address(vault), bytes4(keccak256("manage(address,bytes,uint256)")), true);
        authority.setRoleCapability(MANAGER_ROLE, address(vault), bytes4(keccak256("manage(address[],bytes[],uint256[])")), true);
        authority.setRoleCapability(TELLER_ROLE, address(vault), BoringVault.enter.selector, true);
        authority.setRoleCapability(TELLER_ROLE, address(vault), BoringVault.exit.selector, true);
        authority.setRoleCapability(UPDATE_EXCHANGE_RATE_ROLE, address(accountant), AccountantWithRateProviders.updateExchangeRate.selector, true);
        authority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);

        // Assign roles
        authority.setUserRole(msg.sender, STRATEGIST_ROLE, true);
        authority.setUserRole(address(manager), MANAGER_ROLE, true);
        authority.setUserRole(address(teller), TELLER_ROLE, true);
        authority.setUserRole(msg.sender, UPDATE_EXCHANGE_RATE_ROLE, true);
        authority.setUserRole(msg.sender, PAUSER_ROLE, true);

        // Add supported assets and rate providers
        teller.addAsset(base);
        accountant.setRateProviderData(base, true, address(0));
        for (uint256 i; i < assets.length; ++i) {
            teller.addAsset(assets[i]);
            accountant.setRateProviderData(assets[i], isPeggedToBase[i], rateProviders[i]);
        }

        emit VaultCreated(address(vault), address(manager), address(teller), address(accountant), address(authority));

        return (address(vault), address(manager), address(teller), address(accountant), address(authority));
    }
}
