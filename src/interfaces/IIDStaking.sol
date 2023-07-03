// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IIDStaking {
    function unstakeUsers(
        uint256 roundId, 
        address[] calldata users
    ) external;
}