// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/SlashingEngine.sol";
import "../src/interfaces/IGTC.sol";

// TODO: learn how to test properly in foundry :')

contract SlashingEngineTest is Test {
    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    IGTC public gtc;
    SlashingEngine public slashingEngine;
    uint256 public constant STAKE_AMOUNT = 100e18;
    address public constant GUARDIAN_1 = address(0x1111111111111111111111111111111111111111);
    address public constant GUARDIAN_2 = address(0x2222222222222222222222222222222222222222);
    address public constant GUARDIAN_3 = address(0x3333333333333333333333333333333333333333);

    function setUp() public {
        // create fork and deal GTC to this address
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        gtc = IGTC(0xDe30da39c46104798bB5aA3fe8B9e0e1F348163F);
        deal(address(gtc), address(this), 10000e18, true);
        // gtc, passport, dao
        slashingEngine = new SlashingEngine(
            address(gtc), 
            0x0E3efD5BE54CC0f4C64e0D186b0af4b7F2A0e95F, 
            0x57a8865cfB1eCEf7253c27da6B4BC3dAEE5Be518
        );
    }

    function testStake() public {
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);
        // Approve the slashingEngine contract to spend our GTC
        gtc.approve(address(slashingEngine), 1e18);
        // Stake some GTC tokens
        //slashingEngine.stake(STAKE_AMOUNT);

        // Check the balance of the contract
        // assertEq(gtc.balanceOf(address(slashingEngine)), STAKE_AMOUNT);

        // // Check the staked amount and rank of the guardian
        // assert.equal(slashingEngine.guardians(address(this)).stakedAmount, STAKE_AMOUNT, "Incorrect staked amount");
        // assert.equal(slashingEngine.guardians(address(this)).rank, 1, "Incorrect guardian rank");

        // // Check the topGuardians array
        // assert.equal(slashingEngine.topGuardians(0), address(this), "Incorrect top guardian");
    }

    function testUnstake() public {
        // Permit and stake some GTC tokens
        // slashingEngine.permitAndStake(STAKE_AMOUNT, uint8(27), bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef), bytes32(0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890));

        // // Unstake the GTC tokens
        // slashingEngine.unstake(STAKE_AMOUNT);

        // // Check the staked amount and rank of the guardian
        // assert.equal(slashingEngine.guardians(address(this)).stakedAmount, 0, "Incorrect staked amount");
        // assert.equal(slashingEngine.guardians(address(this)).rank, 65530, "Incorrect guardian rank");

        // // Check the topGuardians array
        // assert.equal(slashingEngine.topGuardians.length, 0, "Top guardians array should be empty");
    }

    function testFlagSybilAccounts() public {
        // Permit and stake some GTC tokens for the guardian
        // slashingEngine.permitAndStake(STAKE_AMOUNT, 0, bytes32(0), bytes32(0));

        // // Flag some sybil accounts
        // address[] memory sybilAccounts = new address[](2);
        // sybilAccounts[0] = GUARDIAN_1;
        // sybilAccounts[1] = GUARDIAN_2;
        // slashingEngine.flagSybilAccounts(sybilAccounts);

        // // Check the flagged accounts and the number of sybil accounts
        // assert.isTrue(slashingEngine.flaggedAccounts(GUARDIAN_1).exists, "Sybil account not flagged");
        // assert.isTrue(slashingEngine.flaggedAccounts(GUARDIAN_2).exists, "Sybil account not flagged");
        // assert.equal(slashingEngine.numSybilAccounts(), 2, "Incorrect number of sybil accounts");

        // // Check the linked list of flagged accounts
        // assert.equal(slashingEngine.firstFlaggedAccount(), GUARDIAN_1, "Incorrect first flagged account");
        // assert.equal(slashingEngine.flaggedAccounts(GUARDIAN_1).next, GUARDIAN_2, "Incorrect next flagged account");
        // assert.equal(slashingEngine.flaggedAccounts(GUARDIAN_2).next, address(0), "Incorrect next flagged account");
    }

    function testUnstakedFlaggedAccounts() public {
        // Flag a sybil account and unstake some GTC tokens for the guardian
        // slashingEngine.flagSybilAccounts(new address[](1)([GUARDIAN_1]));
        // slashingEngine.permitAndStake(STAKE_AMOUNT, 0, bytes32(0), bytes32(0));

        // // Unstake and flag the guardian's account
        // slashingEngine.unstakedFlaggedAccounts(GUARDIAN_1);

        // // Check the staked amount and rank of the guardian
        // assert.equal(slashingEngine.guardians(address(this)).stakedAmount, 0, "Incorrect staked amount");
        // assert.equal(slashingEngine.guardians(address(this)).rank, 65530, "Incorrect guardian rank");

        // // Check the flagged accounts and the number of sybil accounts
        // assert.isTrue(!slashingEngine.flaggedAccounts(GUARDIAN_1).exists, "Flagged account not removed");
        // assert.equal(slashingEngine.numSybilAccounts(), 0, "Incorrect number of sybil accounts");
    }
}

