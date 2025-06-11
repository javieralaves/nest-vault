// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ISwapper} from "src/interfaces/ISwapper.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract MockSwapper is ISwapper {
    function swap(ERC20 tokenIn, ERC20 tokenOut, uint256 amountIn, address recipient) external returns (uint256) {
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        MockERC20(address(tokenOut)).mint(recipient, amountIn);
        return amountIn;
    }
}
