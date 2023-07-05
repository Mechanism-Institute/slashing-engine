// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ERC20} from "../src/ERC20.sol";
import {SlashingEngine} from "../src/SlashingEngine.sol";

// TODO: learn how to test properly in foundry :')

contract SlashingEngineTest is Test {
    using stdStorage for StdStorage;

    ERC20 public gtc;
    SlashingEngine public slashingEngine;
    uint256 public constant STAKE_AMOUNT = 100e18;
    uint256 public constant UNSTAKE_AMOUNT = 50e18;
    address public constant GUARDIAN_1 = address(0x1111111111111111111111111111111111111111);
    address public constant GUARDIAN_2 = address(0x2222222222222222222222222222222222222222);
    address public constant GUARDIAN_3 = address(0x3333333333333333333333333333333333333333);

    function setUp() public {
        // using a new GTC contract, because I was struggling with deal on a mainnet fork
        gtc = new ERC20("Gitcoin", "GTC", 18);
        deal(address(gtc), address(this), 10000e18, true);
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

        // Now, I want to check if the rank + topGuardians array is properly set
        // However, this call currently results in an index out of bounds error
        // even though I can see the correct values when I run forge test -vvv 
        // I don't know why...
        // stdstore
        //     .target(address(slashingEngine))
        //     .sig("guardians(address)")
        //     .with_key(address(this))
        //     .depth(3); 
    }

    function test_unstake() public {
        uint256 initialBalance = gtc.balanceOf(address(this));
        assertEq(initialBalance, 10000e18, "Incorrect initial balance");
        
        gtc.approve(address(slashingEngine), STAKE_AMOUNT);
        slashingEngine.stake(STAKE_AMOUNT);

        slashingEngine.unstake(UNSTAKE_AMOUNT);

        assertEq(gtc.balanceOf(address(slashingEngine)), UNSTAKE_AMOUNT);
    }

    function test_flagSybilAccounts() public {

    }

    function test_unstakedFlaggedAccounts() public {
        
    }
}

