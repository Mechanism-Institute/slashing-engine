// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 rawAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
