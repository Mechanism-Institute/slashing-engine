// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from './ERC20.sol';
import {IERC20Permit} from "./interfaces/IERC20Permit.sol";
import {IIDStaking} from "./interfaces/IIDStaking.sol";

// TODO: slashing a guardian, or having a guardian unstake, currently leaves fewer guardians in the array, and some address (who is
// currently unranked) should be slotted into the newly opened spot. I could adapt the orderGuardians function to achieve this somehow?
// TODO: consider nonReentrant modifiers if I absolutely have to.

contract SlashingEngine {
    struct Guardian {
        uint256 stakedAmount;
        uint256 rank;
        uint256 votes;
    }

    struct FlaggedAccount {
        uint256 amountCommitted;
        address next;
        bool exists;
    }

    mapping(address => Guardian) public guardians;
    uint8 public immutable MAX_GUARDIANS = 21;
    address[] public topGuardians;

    // These variables are used to create a linked list of flagged accounts,
    // which is more gas efficient than looping over an array.
    mapping(address => FlaggedAccount) public flaggedAccounts;
    mapping(address => mapping(address => bool)) internal flaggedByGuardian;
    address public firstFlaggedAccount;
    address public lastFlaggedAccount;
    uint256 public numSybilAccounts;

    ERC20 public immutable gtc;
    IIDStaking public passport;
    // Used to ensure only the DAO can update the variables below
    address public immutable dao;

    uint256 public VOTES_THRESHOLD = 7;
    uint256 public NO_RANK = 65530;

    // Used in the confidenceThreshold function, which multiplies the highest amount
    // staked in the topGuardians array by this number. Any flagged account with more than
    // that highest amount staked * this number will be slashed. 
    // The lower this number is, the more confident the DAO is in our guardians.
    uint8 public CONFIDENCE = 2;

    event GuardianStaked(address indexed guardian, uint256 indexed amount, uint256 indexed newRank);
    event GuardianUnstaked(address indexed guardian, uint256 indexed amount, uint256 indexed oldRank);
    event GuardianSlashed(address indexed guardian, uint256 indexed amount, uint256 indexed oldRank);
    event SybilAccountsFlagged(address indexed sybil, address indexed guardian);

    modifier onlyDAO() {
        require(msg.sender == dao, "Only DAO can call");
        _;
    }

    constructor(
        address _gtc,
        address _passport,
        address _dao
    ) {
        gtc = ERC20(_gtc);
        passport = IIDStaking(_passport);
        // TODO: get the minimal interface for the DAO needed in this context
        dao = address(_dao);
        // Initialize the topGuardians array. It must be fixed in solidity, hence
        // the immutable key word added above.
        topGuardians = new address[](MAX_GUARDIANS);
    }

    /**
     * @notice          enables anyone to stake GTC to become a guardian. The top 21 stakers become
     *                  guardians - everyone else remains unstaked. The top 21 are stored in an ordered array.
     * @param amount    the amount of GTC being staked
     */
    function stake(uint256 amount) public {
        require(amount > 0, "Must stake more than 0");
        
        gtc.transferFrom(msg.sender, address(this), amount);
        
        guardians[msg.sender].stakedAmount += amount;
        uint256 newRank = calculateRank(msg.sender);
        guardians[msg.sender].rank = newRank;
        orderGuardians(msg.sender, newRank);
        
        emit GuardianStaked(msg.sender, amount, newRank);
    }

    /**
     * @notice          uses the permit() functionality in the GTC contract to allow any address to
     *                  stake some amount of GTC to become a guardian. Permit will become obsolete
     *                  with SCAs, but it is still better than batching.
     * @param _amount   the amount of GTC being staked
     * @param v         a signature recovery identity variable included in Ethereum, in addition to the r and s below
     * @param r         standard ECDSA parameter
     * @param s         standard ECDSA parameter
     */
    function permitAndStake(uint256 _amount, uint8 v, bytes32 r, bytes32 s) external {
        IERC20Permit(address(gtc)).permit(msg.sender, address(this), _amount, 10 minutes, v, r, s);
        stake(_amount);
    }

    /**
     * @notice          enables guardians who have staked GTC to withdraw any amount of that GTC up to the total
     *                  after which it reorders the topGuardians array
     * @param amount    the amount of GTC to be withdrawn
     */
    function unstake(uint256 amount) external {
        require(guardians[msg.sender].stakedAmount > 0, "Nothing to withdraw");
        
        uint256 oldRank = guardians[msg.sender].rank;
        
        if (oldRank < MAX_GUARDIANS) {
            // if the withdrawal is the full amount, we can just set their ranking to NO_RANK
            // and shift everyone up, else we need to recalculate the ranking and reorder accordingly
            if (guardians[msg.sender].stakedAmount == amount) {
                for (uint256 i = oldRank + 1; i < topGuardians.length; i++) {
                    if (topGuardians[i] != address(0)) {
                        address nextGuardian = topGuardians[i];
                        guardians[nextGuardian].rank--;
                    } else {
                        break;
                    }
                }
                guardians[msg.sender].rank = NO_RANK;
                guardians[msg.sender].stakedAmount = 0;
                removeTopGuardian(oldRank);
            } else {
                guardians[msg.sender].stakedAmount -= amount;
                removeTopGuardian(oldRank);
                uint256 newRank = calculateRank(msg.sender);
                guardians[msg.sender].rank = newRank;
                orderGuardians(msg.sender, newRank);
            }
        } else {
            guardians[msg.sender].stakedAmount -= amount;
        }

        gtc.transfer(msg.sender, amount);

        emit GuardianUnstaked(msg.sender, amount, oldRank);
    }

    /**
     * @notice          enables any of the topGuardians to submit an array of addresses they believe to be sybils.
                        We use a linked list here, rather than an array to handle the case where large lists of
                        accounts are found and submitted, which would cost too much gas to loop through on chain.
     * @param accounts  the array of accounts considered to be sybils by this guardian 
     */
    function flagSybilAccounts(address[] calldata accounts) external {
        require(guardians[msg.sender].stakedAmount > 0, "Not a guardian");
        require(guardians[msg.sender].rank < MAX_GUARDIANS, "Not a topGuardian");

        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];

            if (!flaggedAccounts[account].exists) {
                flaggedAccounts[account] = FlaggedAccount({
                    amountCommitted: 0,
                    next: address(0),
                    exists: true
                });

                if (numSybilAccounts == 0) {
                    firstFlaggedAccount = account;
                } else {
                    flaggedAccounts[lastFlaggedAccount].next = account;
                }

                lastFlaggedAccount = account;
                numSybilAccounts++;
            }

            // Check if the guardian has already flagged the account
            if (!flaggedByGuardian[account][msg.sender]) {
                flaggedByGuardian[account][msg.sender] = true;
                flaggedAccounts[account].amountCommitted += guardians[msg.sender].stakedAmount;

                emit SybilAccountsFlagged(account, msg.sender);
            }
        }
    }

    /**
     * @notice          enables anyone to cause accounts flagged as sybils, who have sufficient GTC committed
     *                  to the claim that they are indeed sybils, to be unstaked from the Passport contract.
     *                  "Sufficient GTC" is here defined by the CONFIDENCE parameter, which the DAO can set.
     *                  Leverages the same linked list defined above when guardians submit sybil addresses.
     *
     *                  This function needs to be called fairly regularly to prevent the linked list from becoming
     *                  too large, which could brick the contract if traversing it exceeds gas limits...
     */
    function unstakedFlaggedAccounts() external {
        uint256 threshold = confidenceThreshold();
        uint256 unstakeCount = 0;
        address currentAccount = firstFlaggedAccount;
        address[] memory unstakeAccounts = new address[](numSybilAccounts);

        while (currentAccount != address(0)) {
            address nextAccount = flaggedAccounts[currentAccount].next;
            uint256 amountCommitted = flaggedAccounts[currentAccount].amountCommitted;

            if (amountCommitted > threshold) {
                unstakeAccounts[unstakeCount] = currentAccount;
                unstakeCount++;
                delete flaggedAccounts[currentAccount];
            } else {
                break; // No need to continue checking further accounts
            }

            currentAccount = nextAccount;
        }

        if (unstakeCount > 0) {
            // TODO: how to fetch the correct latest round?
            //uint256 roundId = passport.latestRound();
            // TODO: check re-entrancy here
            passport.unstakeUsers(1, unstakeAccounts);
            numSybilAccounts -= unstakeCount;

            // Update the firstFlaggedAccount if it has been removed
            if (numSybilAccounts == 0) {
                firstFlaggedAccount = address(0);
            } else if (!flaggedAccounts[firstFlaggedAccount].exists) {
                firstFlaggedAccount = flaggedAccounts[firstFlaggedAccount].next;
            }
        }
    }

    /**
     * @notice          enables any current guardian to vote to slash another guardian who they believe
     *                  to be behaving maliciously (i.e. submitting accounts as sybils which are provably
     *                  not sybils).
     * @param guardian  the guardian to be slashed
     */
    function slashGuardian(address guardian) external {
        require(guardians[msg.sender].stakedAmount > 0, "Not a guardian");
        require(guardians[msg.sender].rank < MAX_GUARDIANS, "Not a topGuardian");

        // Increment the votes against the specified guardian
        guardians[guardian].votes++;

        require(guardians[guardian].votes >= VOTES_THRESHOLD, "Not enough votes yet");

        // First, remove the guardian from topGuardians array
        uint256 oldRank = guardians[guardian].rank;
        removeTopGuardian(oldRank);

        // Then, update the rankings in the topGuardians array
        for (uint256 i = oldRank + 1; i < topGuardians.length; i++) {
            if (topGuardians[i] != address(0)) {
                address nextGuardian = topGuardians[i];
                guardians[nextGuardian].rank--;
            } else {
                break;
            }
        }

        // Finally, slash the guardian's stake and reset their ranking
        // We leave the votes as is, because once voted out, the same account
        // should not be able to become a guardian again
        uint256 slashedAmount = guardians[guardian].stakedAmount;
        guardians[guardian].stakedAmount = 0;
        guardians[guardian].rank = NO_RANK;

        emit GuardianSlashed(guardian, slashedAmount, oldRank);
    }

    function updatePassport(address newPassport) external onlyDAO {
        passport = IIDStaking(newPassport);
    }

    function updateVoteThreshold(uint256 newThreshold) external onlyDAO {
        VOTES_THRESHOLD = newThreshold;
    }

    function updateConfidence(uint8 newMultiplier) external onlyDAO {
        CONFIDENCE = newMultiplier;
    }

    function isGuardian(address check) external view returns (bool) {
        if (guardians[check].rank <= MAX_GUARDIANS) {
            return true;
        }
        return false;
    }

    /**
     * @notice          iterate over the topGuardians array to figure out where
     *                  the new guardian fits. OK to use this loop given the size
     *                  is fixed to 21.
     * @param guardian  the guardian for whom we are calculating a new ranking
     */
    function calculateRank(address guardian) internal view returns (uint256) {
        // TODO: this means that everyone outside MAX_GUARDIANS receives no rank,
        // which is gas efficient, but means we can't load a new guardian automatically
        // when some unstakes or is slashed. Is there a better way?
        uint256 rank = NO_RANK;
        uint256 stakedAmount = guardians[guardian].stakedAmount;

        // Iterate over the existing guardians in descending order
        for (uint256 i = 0; i < topGuardians.length; i++) {
            address existingGuardian = topGuardians[i];
            
            if (guardians[existingGuardian].stakedAmount < stakedAmount) {
                rank = uint256(i);
                break;
            }
        }

        return rank;
    }

    /**
     * @notice          using the address and new ranking, this reorders the topGuardians array to ensure
     *                  that it is always sorted in a descending order according to how much each guardian
     *                  has staked.
     * @param guardian  the guardian to insert into the topGuardians array
     * @param newRank   the rank at which to insert the new guardian
     */
    function orderGuardians(address guardian, uint256 newRank) internal {
        if (newRank < MAX_GUARDIANS) {
            // If there are already the max number of guardians, remove the lowest-ranked guardian
            if (topGuardians[MAX_GUARDIANS - 1] != address(0)) {
                address lowestGuardian = topGuardians[MAX_GUARDIANS - 1];
                guardians[lowestGuardian].rank = NO_RANK; // Reset the rank of the removed guardian
                topGuardians.pop();
            }

            // Shift the rankings of guardians below the new guardian
            for (uint256 i = newRank; i < topGuardians.length; i++) {
                address guardianToShift = topGuardians[i];
                guardians[guardianToShift].rank++;
            }

            // Insert the new guardian at the correct rank in the topGuardians array
            topGuardians[newRank] = guardian;
        } 
    }

    /**
     * @notice          helper function to remove a guardian when slashed or withdrawing.
     *                  It's kinda ugly, but seeing as the guardians array is only 21 members,
     *                  it should suffice.
     * @param oldRank   the index from which we will be removing this guardian, equal to their rank.
     */
    function removeTopGuardian(uint256 oldRank) internal {
        for (uint256 i = topGuardians.length - 1; i > oldRank; i--) {
            topGuardians[i] = topGuardians[i - 1];
        }
        topGuardians[topGuardians.length - 1] = address(0);
    }

    /**
     * @notice          takes the amount staked by the topGuardian and multiplies it by some factor set by the DAO.
     *                  This approach makes sense if you consider that we never want just one guardian to flag an account
     *                  as a sybil and have that exceed the threshold after which such accounts are unstaked.
     */
    function confidenceThreshold() internal view returns (uint256) {
        address top = topGuardians[0];
        return guardians[top].stakedAmount * CONFIDENCE;
    }

}
