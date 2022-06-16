// SPDX-License-Identifier: MIT
// @author st4rgard3n
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface MolochDAO {

        struct Member {
        address delegateKey; // the key responsible for submitting proposals and voting - defaults to member address unless updated
        uint256 shares; // the # of voting shares assigned to this member
        uint256 loot; // the loot amount available to this member (combined with shares on ragequit)
        bool exists; // always true once a member has been created
        uint256 highestIndexYesVote; // highest proposal index # on which the member voted YES
        uint256 jailed; // set to proposalIndex of a passing guild kick proposal for this member, prevents voting on and sponsoring proposals
    }

        function members(address memberAddress) external returns (Member calldata member);
    }

interface Token {

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

}

contract RiteOfMoloch is ERC721, AccessControl {
    using Counters for Counters.Counter;

    // role constants
    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant OPERATOR = keccak256("OPERATOR");

    /*************************
     MAPPING STRUCTS EVENTS
     *************************/

    // logs new initiation data
    event Initiation(address newInitiate, address benefactor, uint256 tokenId, uint256 stake);

    // logs data when failed initiates get slashed
    event Sacrifice(address sacrifice, uint256 slashedAmount, address slasher);

    // initiation participant token balances
    mapping(address => uint256) private _staked;

    // the time a participant joined the initiation
    mapping(address => uint256) public initiationStart;

    // the number of user's a member has sacrificed
    mapping(address => uint256) public totalSlash;

    /*************************
     STATE VARIABLES
     *************************/

    Counters.Counter private _tokenIdCounter;

    MolochDAO internal _dao;
    Token internal _token;

    address[] allInitiates;

    // minimum amount of dao shares required to be considered a member
    uint256 internal _minimumShare;

    // minimum amount of staked tokens required to join the initiation
    uint256 public minimumStake;

    // maximum length of time for initiates to succeed at joining
    uint256 public maximumTime;

    // DAO treasury address
    address treasury;

    constructor(address daoAddress, address tokenAddress, uint256 shareThreshold) ERC721("Rite of Moloch", "RITE") {

        // Set the interface for accessing the DAO's public members mapping
        _dao = MolochDAO(daoAddress);

        // Store the treasury daoAddress
        treasury = daoAddress;

        // Set the interface for accessing the required staking token
        _token = Token(tokenAddress);

        // Set the minimum shares
        _minimumShare = shareThreshold;

        // grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN, msg.sender);
        _grantRole(OPERATOR, msg.sender);

        // setup the ADMIN role to manage the OPERATOR role
        _setRoleAdmin(OPERATOR, ADMIN);

    }

    /*************************
     MODIFIERS
     *************************/

    /**
    * @dev Modifier for preventing calls from contracts
    * Safety feature for preventing malicious contract call backs
    */
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract!");
        _;
    }

    /**
    * @dev Modifier for enforcing function callable from DAO members only
    * Allows decentralized control by DAO members
    */
    modifier onlyMember() {
        _checkMember();
        _;
    }

    /*************************
     USER FUNCTIONS
     *************************/

    /**
    * @dev Allows users to join the DAO initiation
    * @param user the address which will be activated for the cohort
    * Stakes required tokens and mints soul bound token
    */
    function joinInitiation(address user) public callerIsUser {

        // enforce the initiate transfers correct tokens to the contract
        require(_stake(user), "Staking failed!");

        // issue a soul bound token
        _soulBind(user);

    }

    /**
    * @dev Claims the life force of failed initiates for the dao
    * @param failedInitiates an array of user's who have failed to join the DAO
    * @param indices the indexes which correspond to the allInitiates array
    */
    function sacrifice(address[] calldata failedInitiates, uint256[] calldata indices) public callerIsUser onlyMember {

        _darkRitual(failedInitiates, indices);

    }

    /*************************
     ACCESS CONTROL FUNCTIONS
     *************************/

    /**
    * @dev Allows DAO members to change the staking requirement
    * @param newMinimumStake the minimum quantity of tokens a user must stake to join the cohort
    */
    function setMinimumStake(uint256 newMinimumStake) public onlyRole(ADMIN) {

        // set the minimum staking requirement
        minimumStake = newMinimumStake;

    }

    /**
    * @dev Allows changing the maximum initiation duration
    * @param newMaxTime the length in seconds until an initiate's stake is forfeit
    */
    function setMaxDuration(uint256 newMaxTime) public onlyRole(OPERATOR) {

        // set the maximum length of time for initiations
        maximumTime = newMaxTime;

    }

    /**
    * @dev Allows changing the DAO member share threshold
    * @param newShareThreshold the number of shares required to be considered a DAO member
    */
    function setShareThreshold(uint256 newShareThreshold) public onlyRole(ADMIN) {

        // set the maximum length of time for initiations
        _minimumShare = newShareThreshold;

    }

    /**
    * @dev Allows DAO members to claim their initiation stake
    * @param userIndex the index that corresponds to the claimant in the allInitiates array
    */
    function claimStake(uint256 userIndex) external callerIsUser onlyMember {

        require(_claim(userIndex), "Claim failed!");

    }

    /*************************
     PRIVATE OR INTERNAL
     *************************/

    /**
    * @dev Stakes the user's tokens
    * @param _user the address to activate for the cohort
    */
    function _stake(address _user) internal virtual returns (bool) {

        // enforce that the initiate hasn't previously staked
        require(_staked[_user] == 0, "Already joined the initiation!");

        // change the initiate's stake total
        _staked[_user] = minimumStake;

        // add the initiate's address to the tracking array
        allInitiates.push(_user);

        return _token.transferFrom(msg.sender, address(this), minimumStake);
    }

    /**
    * @dev Claims the successful new members stake
    */
    function _claim(uint256 _userIndex) internal virtual returns (bool) {

        // enforce that the initiate has stake
        require(_staked[msg.sender] > 0, "User has no stake!!");

        // enforce that the function caller and index match
        require(allInitiates[_userIndex] == msg.sender, "Can only claim your own stake!");

        // store the user's balance
        uint256 balance = _staked[msg.sender];

        // adjust the balance
        _staked[msg.sender] = 0;

        // the initiate has graduated; delete them from initiate tracking
        delete allInitiates[_userIndex];

        // return the new member's original stake
        return _token.transferFrom(address(this), msg.sender, balance);

    }

    /**
    * @dev Mints soul bound tokens to the initiate
    * @param _user the recipient of the cohort SBT
    */
    function _soulBind(address _user) internal virtual {

        // enforce that the user hasn't been an initiate before
        require(balanceOf(_user) == 0, "You were sacrificed in a Dark Ritual!");

        // store the current token counter
        uint256 tokenId = _tokenIdCounter.current();

        // log the initiation data
        emit Initiation(_user, msg.sender, tokenId, minimumStake);

        // increment the token counter
        _tokenIdCounter.increment();

        // mint the user's soul bound initiation token
        _safeMint(_user, tokenId);
    }

    /**
    * @dev Claims failed initiate tokens for the DAO
    * @param _failedInitiates an array of user's who have failed to join the DAO
    * @param _indices the indexes which correspond to the allInitiates array
    */
    function _darkRitual(address[] calldata _failedInitiates, uint256[] calldata _indices) internal virtual {

        // enforce that the array lengths match
        require(_failedInitiates.length == _indices.length, "Arrays don't match!");

        // the total amount of blood debt
        uint256 total;

        for (uint256 i = 0; i < _failedInitiates.length; ++i) {

            // store each initiate's address
            address initiate = _failedInitiates[i];

            // access each initiate's starting time
            uint256 startTime = initiationStart[initiate];

            // access each initiate's balance
            uint256 balance = _staked[initiate];

            // enforce each initiate is ready to be sacrificed
            require(block.timestamp - startTime > maximumTime, "You can't sacrifice newbies!");

            // enforce that the failed initiate and indices arrays are a match
            require(_failedInitiates[i] == allInitiates[_indices[i]], "You can't sacrifice the innocent!");

            // change the sacrifice's balance
            _staked[initiate] = 0;

            // calculate the total blood debt
            total += balance;

            // log sacrifice data
            emit Sacrifice(initiate, balance, msg.sender);

            // remove the sacrifice from the initiate array
            delete allInitiates[_indices[i]];

        }

        // drain the life force from the sacrifice
        require(_token.transferFrom(address(this), treasury, total), "Failed Sacrifice!");

        // increase the slasher's essence
        totalSlash[msg.sender] += _failedInitiates.length;

    }

    /**
    * @dev Authenticates users through the DAO contract
    */
    function _checkMember() internal virtual {

        // access membership data from the DAO
        MolochDAO.Member memory member = _dao.members(msg.sender);

        // access the user's total shares
        uint256 shares = member.shares;

        // enforce that the user is a member
        require(shares >= _minimumShare, "You must be a member!");
    }

    /*************************
     VIEW AND PURE FUNCTIONS
     *************************/

    /**
    * @dev returns all initiate addresses that are ready to be sacrificed; and their element position in the
    * initiate array
    */
    function getSacrifices() public view returns (address[] memory failedInitiates, uint256[] memory indices) {

        // an array to store our potential sacrifices
        address[] memory sacrifices;

        // the indices that correspond to each sacrifice
        uint256[] memory sacrificeIndices;

        // increment each time we find a proper sacrifice
        uint256 count;

        for (uint256 i = 0; i < allInitiates.length; ++i) {

            // access each initiate's start time
            uint256 startTime = initiationStart[allInitiates[i]];

            // calculate the time an initiate has been in the cohort
            uint256 duration = block.timestamp - startTime;

            if (duration >= maximumTime) {

                // add the failed initiate address to the sacrifice array
                sacrifices[count] = allInitiates[i];

                // add their indice
                sacrificeIndices[count] = i;

                // increment our counter
                count += 1;

            }

        }

        return(sacrifices, sacrificeIndices);

    }

    /*************************
     OVERRIDES
     *************************/

    function _baseURI() internal pure override returns (string memory) {
        return "https://www.raidguild.org/riteofraidguild/";
    }

    // Cohort NFTs cannot be transferred
    function _transfer(address from, address to, uint256 tokenId)
        internal
        virtual
        override {
        revert();
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}
