// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

interface ISwapper {
    function swap(ERC20 tokenIn, ERC20 tokenOut, uint256 amountIn, address recipient) external returns (uint256 amountOut);
}
