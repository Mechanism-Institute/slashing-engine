// SPDX-License-Identifier: MIT
// TODO: change back to 0.6.12 before deploying
pragma solidity 0.8.17;
pragma experimental ABIEncoderV2;

interface IGTC {
    function setMinter(address minter_) external;

    function setGTCDist(address GTCDist_) external;

    function mint(address dst, uint rawAmount) external;

    function allowance(address account, address spender) external view returns (uint);

    function approve(address spender, uint rawAmount) external returns (bool);

    function permit(address owner, address spender, uint rawAmount, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    function balanceOf(address account) external view returns (uint);

    function transfer(address dst, uint rawAmount) external returns (bool);

    function transferFrom(address src, address dst, uint rawAmount) external returns (bool);

    function delegate(address delegatee) external;

    function delegateOnDist(address delegator, address delegatee) external;

    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) external;
    
    function getCurrentVotes(address account) external view returns (uint96);
    
    function getPriorVotes(address account, uint blockNumber) external view returns (uint96);

}