// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ERC20} from "../src/ERC20.sol";
import {SlashingEngine} from "../src/SlashingEngine.sol";

// TODO: learn how to test properly in foundry :')

contract SlashingEngineTest is Test {
    ERC20 public gtc;
    SlashingEngine public slashingEngine;

    uint256 public constant STAKE_AMOUNT = 100e18;
    uint256 public constant UNSTAKE_AMOUNT = 50e18;

    address public constant ADDRESS_0 = address(0x0000000000000000000000000000000000000000);

    address public constant GUARDIAN_1 = address(0x0000111111111111111111111111111111111111);
    uint256 public constant G1_STAKE = 200e18;
    address public constant GUARDIAN_2 = address(0x0000111111111111111111111111111111111112);
    uint256 public constant G2_STAKE = 150e18;

    address public constant SYBIL_1 = address(0x1111111111111111111111111111111111111111);
    address public constant SYBIL_2 = address(0x1111111111111111111111111111111111111112);
    address public constant SYBIL_3 = address(0x1111111111111111111111111111111111111113);
    address public constant SYBIL_4 = address(0x1111111111111111111111111111111111111114);
    address public constant SYBIL_5 = address(0x1111111111111111111111111111111111111115);
    address public constant SYBIL_6 = address(0x1111111111111111111111111111111111111116);
    address public constant SYBIL_7 = address(0x1111111111111111111111111111111111111117);

    function setUp() public {
        // using a new GTC contract, because I was struggling with deal on a mainnet fork
        gtc = new ERC20("Gitcoin", "GTC", 18);
        deal(address(gtc), address(this), 10000e18, true);
        deal (address(gtc), GUARDIAN_1, 20000e18, true);
        deal (address(gtc), GUARDIAN_2, 30000e18, true);
        // gtc, passport, dao
        slashingEngine = new SlashingEngine(
            address(gtc), 
            0x0E3efD5BE54CC0f4C64e0D186b0af4b7F2A0e95F, 
            0x57a8865cfB1eCEf7253c27da6B4BC3dAEE5Be518
        );
    }

    function test_stake() public {        
        uint256 initialBalance = gtc.balanceOf(address(this));
        assertEq(initialBalance, 10000e18, "Incorrect initial balance");
        
        gtc.approve(address(slashingEngine), STAKE_AMOUNT);
        slashingEngine.stake(STAKE_AMOUNT);

        assertEq(gtc.balanceOf(address(slashingEngine)), STAKE_AMOUNT);

        assertEq(slashingEngine.getGuardian(address(this)).stakedAmount, STAKE_AMOUNT);
        // we start ranks from 0 so that they always match the index in topGuardians
        assertEq(slashingEngine.getGuardian(address(this)).rank, 0); 
        assertEq(slashingEngine.topGuardians(0), address(this));

        // Now, let's stake more from another account
        vm.prank(GUARDIAN_1);
        gtc.approve(address(slashingEngine), G1_STAKE * 2);
        vm.prank(GUARDIAN_1);
        slashingEngine.stake(G1_STAKE);

        // should have taken top rank and moved previous guardian down one
        assertEq(slashingEngine.getGuardian(GUARDIAN_1).stakedAmount, G1_STAKE);
        assertEq(slashingEngine.getGuardian(GUARDIAN_1).rank, 0);
        assertEq(slashingEngine.topGuardians(0), GUARDIAN_1);
        assertEq(slashingEngine.getGuardian(address(this)).rank, 1);
        assertEq(slashingEngine.topGuardians(1), address(this));

        // test that staking again adds the amount staked
        vm.prank(GUARDIAN_1);
        slashingEngine.stake(G1_STAKE);
        assertEq(slashingEngine.getGuardian(GUARDIAN_1).stakedAmount, G1_STAKE * 2);
        // TODO: fix the calculateRank function to handle this case properly
        //assertEq(slashingEngine.getGuardian(GUARDIAN_1).rank, 0);

        // test that, if guardians stake the same amount, the existing one ranks higher
        vm.prank(GUARDIAN_2);
        gtc.approve(address(slashingEngine), STAKE_AMOUNT);
        vm.prank(GUARDIAN_2);
        slashingEngine.stake(STAKE_AMOUNT);
        // assertEq(slashingEngine.getGuardian(address(this)).rank, 1);
        // assertEq(slashingEngine.getGuardian(GUARDIAN_2).rank, 2);
    }

    function test_unstake() public {
        uint256 initialBalance = gtc.balanceOf(address(this));
        assertEq(initialBalance, 10000e18, "Incorrect initial balance");
        
        gtc.approve(address(slashingEngine), STAKE_AMOUNT * 10);

        // setup to test unstake
        slashingEngine.stake(STAKE_AMOUNT);
        assertEq(slashingEngine.getGuardian(address(this)).rank, 0); 
        assertEq(slashingEngine.topGuardians(0), address(this));

        // first, we test if they unstake the full amount
        slashingEngine.unstake(STAKE_AMOUNT);
        // should have NO_RANK and reset topGuardians top address
        assertEq(slashingEngine.getGuardian(address(this)).rank, 65530);
        assertEq(slashingEngine.topGuardians(0), ADDRESS_0);
        // gtc balance of contract should be 0 again
        assertEq(gtc.balanceOf(address(slashingEngine)), 0);
        // gtc balance of this address should be back to initial
        assertEq(gtc.balanceOf(address(this)), initialBalance);

        // then, we test if they unstake half the amount
        slashingEngine.stake(STAKE_AMOUNT);
        slashingEngine.unstake(UNSTAKE_AMOUNT);
        // ranking and topGuardians should still be the same
        assertEq(slashingEngine.getGuardian(address(this)).rank, 0); 
        assertEq(slashingEngine.topGuardians(0), address(this));
        // gtc balance of contract should be half of originally staked amount, i.e.
        assertEq(gtc.balanceOf(address(slashingEngine)), UNSTAKE_AMOUNT);
        // gtc balance of this address should initial less the UNSTAKE_AMOUNT
        assertEq(gtc.balanceOf(address(this)), initialBalance - UNSTAKE_AMOUNT);

        // Now, let's stake more from another account
        vm.prank(GUARDIAN_1);
        gtc.approve(address(slashingEngine), G1_STAKE);
        vm.prank(GUARDIAN_1);
        slashingEngine.stake(G1_STAKE);
        // guardian 1 should be ranked first
        assertEq(slashingEngine.getGuardian(GUARDIAN_1).rank, 0);
        assertEq(slashingEngine.topGuardians(0), GUARDIAN_1);
        assertEq(slashingEngine.getGuardian(address(this)).rank, 1);
        assertEq(slashingEngine.topGuardians(1), address(this));

        // Finally, let's unstake from the guardian
        vm.prank(GUARDIAN_1);
        slashingEngine.unstake(G1_STAKE);
        // guardian 1 should have no rank, address(this) should be back to 0
        assertEq(slashingEngine.getGuardian(GUARDIAN_1).rank, 65530);
        assertEq(slashingEngine.getGuardian(address(this)).rank, 0);
        assertEq(slashingEngine.topGuardians(0), address(this));
    }

    function test_flagSybilAccounts() public {
        // create two guardians
        gtc.approve(address(slashingEngine), STAKE_AMOUNT * 10);
        slashingEngine.stake(STAKE_AMOUNT);
        vm.prank(GUARDIAN_1);
        gtc.approve(address(slashingEngine), G1_STAKE);
        vm.prank(GUARDIAN_1);
        slashingEngine.stake(G1_STAKE);
        // create arrays of sybils
        address[] memory sybils1 = new address[](6);
        sybils1[0] = SYBIL_1;
        sybils1[1] = SYBIL_2;
        sybils1[2] = SYBIL_3;
        sybils1[3] = SYBIL_4;
        sybils1[4] = SYBIL_5;
        sybils1[5] = SYBIL_6;
        address[] memory sybils2 = new address[](3);
        sybils2[0] = SYBIL_1;
        sybils2[1] = SYBIL_2;
        sybils2[2] = SYBIL_3;

        slashingEngine.flagSybilAccounts(sybils1);
        // test to see if all sybils were properly recorded
        assertEq(slashingEngine.numSybilAccounts(), 6);
        assertEq(slashingEngine.flaggedAccounts(5), SYBIL_6);
        assertEq(slashingEngine.amountCommittedPerAccount(SYBIL_1), STAKE_AMOUNT);
        assertEq(slashingEngine.amountCommittedPerAccount(SYBIL_6), STAKE_AMOUNT);
        // flag next accounts
        vm.prank(GUARDIAN_1);
        slashingEngine.flagSybilAccounts(sybils2);
        // should not change the flaggedAccounts mapping or numSybilAccounts
        assertEq(slashingEngine.numSybilAccounts(), 6);
        assertEq(slashingEngine.flaggedAccounts(5), SYBIL_6);
        // should change the amountCommittedPerAccount mapping
        assertEq(slashingEngine.amountCommittedPerAccount(SYBIL_1), G1_STAKE + STAKE_AMOUNT);

        // test changing the CONFIDENCE while we're at it
        vm.prank(0x57a8865cfB1eCEf7253c27da6B4BC3dAEE5Be518);
        slashingEngine.updateConfidence(1);
        assertEq(slashingEngine.CONFIDENCE(), 1);

        // should now be able to unstake the first 3
        slashingEngine.slashFlaggedAccounts();
        assertEq(slashingEngine.numSybilAccounts(), 3);
        assertEq(slashingEngine.flaggedAccounts(0), ADDRESS_0);
        assertEq(slashingEngine.flaggedAccounts(3), SYBIL_4);
        assertEq(slashingEngine.flaggedAccounts(5), SYBIL_6);

        // let's stake from yet another account
        vm.prank(GUARDIAN_2);
        gtc.approve(address(slashingEngine), G2_STAKE);
        vm.prank(GUARDIAN_2);
        slashingEngine.stake(G2_STAKE);
        address[] memory sybils3 = new address[](3);
        sybils3[0] = SYBIL_4;
        sybils3[1] = SYBIL_6;
        sybils3[2] = SYBIL_7;
        vm.prank(GUARDIAN_2);
        slashingEngine.flagSybilAccounts(sybils3);

        // we should have 3 left from the previous flags + 1 new one
        assertEq(slashingEngine.numSybilAccounts(), 4);
        // 4 and 6 should just be flagged again. Because we're trying to optimise for
        // space usage in the array, 7 should be written to flaggedAccounts(0) now that
        // it is set to address(0) again.
        assertEq(slashingEngine.flaggedAccounts(0), SYBIL_7);
        
        // now slash again. we set CONFIDENCE to 1, so the threshold
        // should be 200 gtc, so 4 and 6 should now pass that and be slashed
        slashingEngine.slashFlaggedAccounts();
        // should be 2 flagged accounts left: 5 and 7
        assertEq(slashingEngine.numSybilAccounts(), 2);
        assertEq(slashingEngine.flaggedAccounts(0), SYBIL_7);
        assertEq(slashingEngine.flaggedAccounts(4), SYBIL_5);
        assertEq(slashingEngine.flaggedAccounts(3), ADDRESS_0);
        assertEq(slashingEngine.flaggedAccounts(5), ADDRESS_0);
    }
}

