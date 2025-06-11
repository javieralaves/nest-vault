// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { DexAggregatorUManager, ERC20 } from "src/micro-managers/DexAggregatorUManager.sol";

contract DailyRebalancer is DexAggregatorUManager {
    struct Allocation {
        ERC20 asset;
        uint16 weight; // scaled by 1e4
    }

    Allocation[] public allocations;
    ERC20 public immutable depositAsset;
    uint16 public constant WEIGHT_SCALE = 1e4;

    event AllocationsUpdated();
    event Rebalanced(uint256 depositAmount);

    constructor(
        address _owner,
        address _manager,
        address _vault,
        address _router,
        address _priceRouter,
        ERC20 _depositAsset
    )
        DexAggregatorUManager(_owner, _manager, _vault, _router, _priceRouter)
    {
        depositAsset = _depositAsset;
    }

    function setAllocations(ERC20[] calldata assets, uint16[] calldata weights) external requiresAuth {
        require(assets.length == weights.length, "len mismatch");
        delete allocations;
        uint256 total;
        for (uint256 i; i < assets.length; ++i) {
            allocations.push(Allocation({asset: assets[i], weight: weights[i]}));
            total += weights[i];
        }
        require(total == WEIGHT_SCALE, "bad weights");
        emit AllocationsUpdated();
    }

    function rebalance(
        bytes32[][][] calldata manageProofs,
        address[][] calldata decodersAndSanitizers,
        bytes[] calldata swapData
    ) external requiresAuth enforceRateLimit {
        uint256 len = allocations.length;
        require(
            len == manageProofs.length && len == decodersAndSanitizers.length && len == swapData.length,
            "bad len"
        );

        uint256 balance = depositAsset.balanceOf(boringVault);
        for (uint256 i; i < len; ++i) {
            uint256 amount = (balance * allocations[i].weight) / WEIGHT_SCALE;
            if (amount == 0) continue;
            swapWith1Inch(manageProofs[i], decodersAndSanitizers[i], depositAsset, amount, allocations[i].asset, swapData[i]);
        }
        emit Rebalanced(balance);
    }
}
