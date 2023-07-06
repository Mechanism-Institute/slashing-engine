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

    address public constant GUARDIAN_1 = address(0x1111111111111111111111111111111111111111);
    uint256 public constant G1_STAKE = 200e18;

    address public constant GUARDIAN_2 = address(0x2222222222222222222222222222222222222222);
    address public constant GUARDIAN_3 = address(0x3333333333333333333333333333333333333333);

    function setUp() public {
        // using a new GTC contract, because I was struggling with deal on a mainnet fork
        gtc = new ERC20("Gitcoin", "GTC", 18);
        deal(address(gtc), address(this), 10000e18, true);
        deal (address(gtc), GUARDIAN_1, 20000e18, true);
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
        gtc.approve(address(slashingEngine), G1_STAKE);
        vm.prank(GUARDIAN_1);
        slashingEngine.stake(G1_STAKE);

        assertEq(slashingEngine.getGuardian(GUARDIAN_1).rank, 0);
        assertEq(slashingEngine.topGuardians(0), GUARDIAN_1);
        assertEq(slashingEngine.getGuardian(address(this)).rank, 1);
        assertEq(slashingEngine.topGuardians(1), address(this));
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

    }

    function test_unstakedFlaggedAccounts() public {
        
    }
}

