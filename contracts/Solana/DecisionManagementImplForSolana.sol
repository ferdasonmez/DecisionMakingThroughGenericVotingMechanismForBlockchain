
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// Decision Management Contract

//import "../utility/UtilityProxy.sol";
//import "./IDecisionManagementImpl.sol";
//import "../genericProposalAction/ProposalActionContract.sol";
//import "../genericProposalAction/IProposalActionContract.sol";
//import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
//import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
//import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
//import { OwnableUpgradeable as MyOwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {AccountMeta, AccountInfo} from 'solana';



contract DecisionManagementImplWithGenericVoting{
    struct VoteGroup {
        uint[] proposalIds; 
        string voteGroupName;
    }
    struct VotingStructure {
        uint votingStructureId; 
        string name;
        VoteCostType voteCostType;
        address tokenAddress;
        uint256 lowerLimit;
        uint256 upperLimit;
        bool onlyYes;
        bool onlyOnce;
    }

    struct Vote {
        uint voteId;
        uint votingStructureId;
        uint proposalId;
        bool yesno;
        uint numericValue;
        address voterAddress;
        uint voterChainId;
        uint chainCurrentVotingWeight;
        uint chainCurrentProposalVotingWeight;
        uint memberCurrentVotingWeight;
        uint memberCurrentProposalVotingWeight;
        
    }



    struct Proposal {
        uint256 id;
        string description;
        address proposingMemberAddress;
        uint proposingMemberChainId;
        uint proposingCommunityId;
        string proposingCommunityName;
        CommunityRestriction communityRestriction;
        mapping(bytes32 =>uint) voted; // using bytes32 hash of address and chain_id 
        mapping(bytes32 => Vote) votes; // using bytes32 hash of address and chain_id
        uint256 numberOfVotes;
        uint256 numberOfYesVotes;
        uint256 numberOfNoVotes;
        uint256 sumOfYesVotes;
        uint256 sumOfNoVotes;
        bool executed;
        bool passed;
        uint quorum;
        uint256 startTime;
        uint256 endTime;
        uint256 votingStructureId;
        uint256 proposalBudget;
        address proposalImplementationAddress;
        string[] tags;
    }
    struct ProposalBasicData {
        uint256 proposalId;
        string description;
        address proposingMemberAddress;
        uint proposingMemberChainId;
        uint proposingCommunityId;
        string proposingCommunityName;
        uint proposalCommunityRestriction;
        uint256 startTime;
        uint256 endTime;
        uint256 votingStructureId;
        string[] tags;
    }
    struct AccountChainPair {
        address account;
        uint chainId;
        string[] tags;
    }

    /*struct CommunityData {
        uint256 id;
        string name;
        AccountChainPair[] members;
        mapping(uint256 => uint256) chainWeights; //chainId =>chainweight
        mapping(bytes => uint256) chainProposalWeights; //keccak (chainId + proposalId) =>chainProposalweight
    }*/

    struct TransferData {
        address sender;
        address receiver;
        uint256 amount;
        string currencyType;
        bytes memo;
    }
    
    struct ContractFunctionCallData {
        address targetContractAddress;
        string targetcontractName;
        string targetfunctionName;
        bytes parameters;
    }
    mapping(uint => VotingStructure) public votingTypeVotingStructure; //VotingType to VotingStructure
    mapping(uint => VotingStructure) public votingStructureIdVotingStructure; //VotingStructureId to VotingStructure
    mapping(uint => string) public chainNames; //chainId to chainName
    mapping(bytes32 => address) public bridgeImplementations;
    enum VotingTypes {
        SingleVote_Free_VotingType,
        SingleVote_OneTokenPerVote_VotingType,
        Limitless_TokenSameAsVote_VotingType,
        Limited_1_to_10_Quadratic_VotingType
    }
    enum chainNamesEnum{
        Ethereum_main_network, 
        Ethereum_classic_main_network, 
        Hardhat, 
        Ganache, 
        Goerli, 
        Palm_testnet, 
        Aurora_testnet
        }

    mapping(chainNamesEnum => uint) public chainEnumToIds;
    mapping(chainNamesEnum => string) public chainEnumToChainName;
    uint NUMBEROFVOTINGSTRUCTURES = 4; 
    address authority;
    struct Community {
        uint id;
        string name;
        uint parentCommunityId;
        uint[] memberChainIds;
        string[] tags;
        uint chainId;
        string chainName;
        string operation;
        string operationAccount;
    }
    modifier needs_authority() {
        for (uint64 i = 0; i < tx.accounts.length; i++) {
            AccountInfo ai = tx.accounts[i];

            if (ai.key == authority && ai.is_signer) {
                _;
                return;
            }
        }

        print("not signed by authority");
        revert();
    }
    // Array to store communities
    Community[] public communities;

    function createCommunity(uint communityId, string memory communityName, uint parentCommunityId, string[] memory tags, uint chainID, string memory chainName) public {
        // Perform checks
        require(bytes(communityName).length > 0, "Community name cannot be empty");
        for (uint64 i = 0; i < tx.accounts.length; i++) {
            AccountInfo ai = tx.accounts[i];
            require(ai.key != address(0), "Invalid account address");
        }
        //require(msg.sender != address(0), "Invalid account address");
        require(chainID > 0, "Invalid chain ID");
        require(tags.length > 0, "At least one tag is required");

        // Create a new community
        Community memory newCommunity;
        newCommunity.id = communityId;
        newCommunity.name = communityName;
        newCommunity.parentCommunityId = parentCommunityId;
        newCommunity.tags = tags;
        newCommunity.chainId = chainID;
        newCommunity.chainName = chainName;
        newCommunity.operation = "+";

        AccountInfo ai = tx.accounts[0];
        newCommunity.operationAccount = addressToString(ai.key);

        // Add the owner as a member in members
        //newCommunity.memberChainIds.push(chainID);
        communities.push(newCommunity);
    }

    // Utility function to convert address to string (for demonstration purposes)
    function addressToString(address account) public pure returns (string memory) {
        return toString(abi.encodePacked(account));
    }

    // Utility function to convert bytes to string (for demonstration purposes)
    function toString(bytes memory data) public pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 * data.length);

        for (uint i = 0; i < data.length; i++) {
            str[2 * i] = alphabet[uint(uint8(data[i] >> 4))];
            str[2 * i + 1] = alphabet[uint(uint8(data[i] & 0x0f))];
        }

        return string(str);
    }
    function initializeChains(string[] memory chainNamesInput,  uint256[] memory chainIds) internal {
        for (uint256 i = 0; i < chainNamesInput.length; i++) {
            chainEnumToChainName[chainNamesEnum(i)] = chainNamesInput[i];
            chainNames[i] = chainNamesInput[i];
            chainEnumToIds[chainNamesEnum(i)] = chainIds[i];
        }
   
    }
    
    function initializeVotingStructures() internal {
    // Initialize Yes/No Voting Structure

    VotingStructure memory singleVoteFreeStructure = VotingStructure(
        1,
        "SingleVote_Free_VotingType",
        VoteCostType.Free,
        address(0), // Address of the token, set to zero address for free voting
        1,
        1, 
        false,
        false
    );
    votingTypeVotingStructure[uint(VotingTypes.SingleVote_Free_VotingType)] = singleVoteFreeStructure;
    votingStructureIdVotingStructure[1] = singleVoteFreeStructure;

    VotingStructure memory singleVoteOneTokenPerVoteVotingStructure = VotingStructure(
        2,
        "SingleVote_OneTokenPerVote_VotingType",
        VoteCostType.OneTokenPerVote,
        address(this), // Set the token address for one token per vote
        1,
        1,
        false,
        false
    );
    votingTypeVotingStructure[uint(VotingTypes.SingleVote_OneTokenPerVote_VotingType)] = singleVoteOneTokenPerVoteVotingStructure;
    votingStructureIdVotingStructure[2] = singleVoteOneTokenPerVoteVotingStructure;
 

    VotingStructure memory limitlessTokenSameAsVoteVotingStructure = VotingStructure(
        3,
        "Limitless_TokenSameAsVote_VotingType",
        VoteCostType.SameAsVoteAmount,
        address(0), // Address of the token, set to zero address for free voting
        1,
        0, // No upper limit
        false,
        false
    );
    votingTypeVotingStructure[uint(VotingTypes.Limitless_TokenSameAsVote_VotingType)] = limitlessTokenSameAsVoteVotingStructure;
    votingStructureIdVotingStructure[3] = limitlessTokenSameAsVoteVotingStructure;

    // Initialize Numeric Range Voting Structure (1 to 10) with Same as Vote Amount
    VotingStructure memory limited1to10QuadraticVotingStructure = VotingStructure(
        4,
        "Limited_1_to_10_Quadratic_VotingType",
        VoteCostType.SameAsVoteAmount,
        address(this), // Set the token address for same as vote amount
        1,
        10,
        false,
        true
    );
    votingTypeVotingStructure[uint(VotingTypes.Limited_1_to_10_Quadratic_VotingType)] = limited1to10QuadraticVotingStructure;
    votingStructureIdVotingStructure[4] = limited1to10QuadraticVotingStructure;

   
}

    constructor(address initial_authority, string[] memory chainNamesInput, uint256[] memory chainIds) {
        authority = initial_authority;
        require(chainNamesInput.length == chainIds.length, "Array lengths must match");
        //@todo votingstructures can also be provided as input
        initializeChains(chainNamesInput, chainIds);
        initializeVotingStructures();
      
    }
    function set_new_authority(address new_authority) needs_authority public {
        authority = new_authority;
    }
    function setBridgeImplementation(
        uint256 fromChainId,
        uint256 toChainId,
        address bridgeImplAddress
    ) external needs_authority {
        bytes32 key = keccak256(abi.encodePacked(fromChainId, toChainId));
        bridgeImplementations[key] = bridgeImplAddress;
    }

    function getBridgeImplementation(
        uint256 fromChainId,
        uint256 toChainId
    ) public view returns (address) {
        if (fromChainId == toChainId) {
            return address(0);
        } else {
            // Replace the following with the actual logic for determining the bridge contract address
            // For example, you could use a mapping to store the bridge contract addresses for different chain pairs
            bytes32 key = keccak256(abi.encodePacked(fromChainId, toChainId));

            return bridgeImplementations[key];
        }
    }

    function getChainId() public view returns (uint256) {

        return 900;
    }
    uint private nonce = 0;
    uint private constant MAX_NONCE = 999999999999999999;
    
    function generateUniqueId() public returns (uint) {
        uint id = (block.timestamp * 1000000000000000000) + nonce;
        nonce = (nonce + 1) % MAX_NONCE;
        return id;
    }

    function getChainName(
        uint256 chainId
    ) public view returns (string memory) {
        return chainNames[chainId];
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual {}

    function getVotingStructures()
        public
        view
        returns (uint[] memory, VotingStructure[] memory)
    {    uint[] memory keys = new uint[](NUMBEROFVOTINGSTRUCTURES);
        VotingStructure[] memory values = new VotingStructure[](NUMBEROFVOTINGSTRUCTURES);

        uint index = 0;
        for (uint i = 0; i < NUMBEROFVOTINGSTRUCTURES; i++) {
          //  if (votingTypeVotingStructure[i].exists) {
                keys[index] = i;
                values[index] = votingTypeVotingStructure[i];
                index++;
         //   }
        }

        return (keys, values);
    }
        enum VoteCostType {
        Free,
        OneTokenPerVote,
        SameAsVoteAmount, 
        Quadratic
    }
    enum CommunityRestriction {
        OnlyProposingCommunity,
        OnlyProposingAndChildren,
        OnlyChildren,
        NotProposingCommunity,
        All
    }
    

    
    Proposal[] proposals;




    event ProposalCreated(
        uint256 indexed proposalId,
        string description,
        address indexed proposingMemberAddress,
        uint proposingMemberChainId,
        uint proposingCommunityId,
        string proposingCommunityName,
        uint256 proposalBudget,
        uint256 numberOfVotes,
        bool executed,
        bool passed,
        uint quorum,
        uint256 startTime,
        uint256 endTime,
        uint256 votingType,
        address proposalImplementationAddress,
        string[] tags
    );
    function createProposal(
        string memory _description,
        uint _communityId,
        string memory _communityName,
        address _proposingMemberAddress,
        uint _proposingMemberChainId,
        CommunityRestriction _communityRestriction,
        VotingStructure memory _votingStructure,
        uint256 _proposalBudget,
        uint _quorum,
        uint256 _startTime,
        uint256 _endTime,
        address _proposalImplementationAddress,
        string[] memory _tags
    ) public returns (uint256 proposalId) {
        uint256 _proposalId = generateUniqueId();

        // Create the new proposal
        Proposal storage proposal = proposals.push();
        
        proposal.id = _proposalId;
        proposal.description = _description;
        proposal.proposingMemberAddress = _proposingMemberAddress;
        proposal.proposingMemberChainId = _proposingMemberChainId;
        proposal.proposingCommunityId = _communityId;
        proposal.proposingCommunityName = _communityName;
        proposal.proposalBudget = _proposalBudget;
        proposal.startTime = _startTime;
        proposal.endTime = _endTime;
        proposal.votingStructureId = _votingStructure.votingStructureId;
        proposal.quorum = _quorum;
        proposal.proposalImplementationAddress = _proposalImplementationAddress;
        proposal.tags = _tags;
        //Set the voting structure for the proposal
        //proposal.votingStructure = _votingStructure;

    // Emit the ProposalCreated event with all the fields
    emit ProposalCreated(
        proposalId,
        proposal.description,
        proposal.proposingMemberAddress,
        proposal.proposingMemberChainId,
        proposal.proposingCommunityId,
        proposal.proposingCommunityName,
        proposal.proposalBudget,
        proposal.numberOfVotes,
        proposal.executed,
        proposal.passed,
        proposal.quorum,
        proposal.startTime,
        proposal.endTime,
        proposal.votingStructureId,
        proposal.proposalImplementationAddress,
        proposal.tags
    );
    }
    mapping(address => bool) private allowedCommunities;

    modifier onlyThroughAllowedCommunities() {
        
        AccountInfo ai = tx.accounts[0];

        require(allowedCommunities[ai.key], "Caller is not an allowed Community contract");
        _;
    }

    function allowCommunity(address communityContract) external needs_authority  {
        allowedCommunities[communityContract] = true;
    }

    function disallowCommunity(address communityContract) external needs_authority  {
        allowedCommunities[communityContract] = false;
    }
  function getProposalBasicInfoAndContraintsWithoutVotesById(uint256 proposalId) public view returns (ProposalBasicData memory proposalBasicData) {
        Proposal storage proposal = proposals[proposalId];

        /*id = proposal.id;
        description = proposal.description;
        proposingMemberAddress = proposal.proposingMemberAddress;
        proposingMemberChainId = proposal.proposingMemberChainId;
        proposingCommunityId = proposal.proposingCommunityId;
        proposingCommunityName = proposal.proposingCommunityName;
        communityRestriction = uint(proposal.communityRestriction);
        /*numberOfVotes = proposal.numberOfVotes;
        numberOfYesVotes = proposal.numberOfYesVotes;
        numberOfNoVotes = proposal.numberOfNoVotes;
        sumOfYesVotes = proposal.sumOfYesVotes;
        sumOfNoVotes = proposal.sumOfNoVotes;
        executed = proposal.executed;
        passed = proposal.passed;
        quorum = proposal.quorum;*/
        /*startTime = proposal.startTime;
        endTime = proposal.endTime;
        votingStructureId = proposal.votingStructureId;*/
        /*proposalBudget = proposal.proposalBudget;
        proposalImplementationAddress = proposal.proposalImplementationAddress;*/
        /*tags = proposal.tags;*/

        //IUtilityImpl.ProposalBasicData memory proposalBasicData;
      
        proposalBasicData.proposalId = proposal.id;
        proposalBasicData.description = proposal.description;
        proposalBasicData.proposingMemberAddress = proposal.proposingMemberAddress;
        proposalBasicData.proposingMemberChainId = proposal.proposingMemberChainId;
        proposalBasicData.proposingCommunityId = proposal.proposingCommunityId;
        proposalBasicData.proposingCommunityName = proposal.proposingCommunityName;
        proposalBasicData.proposalCommunityRestriction = uint(proposal.communityRestriction);
        /*numberOfVotes = proposal.numberOfVotes;
        numberOfYesVotes = proposal.numberOfYesVotes;
        numberOfNoVotes = proposal.numberOfNoVotes;
        sumOfYesVotes = proposal.sumOfYesVotes;
        sumOfNoVotes = proposal.sumOfNoVotes;
        executed = proposal.executed;
        passed = proposal.passed;
        quorum = proposal.quorum;*/
        proposalBasicData.startTime = proposal.startTime;
        proposalBasicData.endTime = proposal.endTime;
        proposalBasicData.votingStructureId = proposal.votingStructureId;
        /*proposalBudget = proposal.proposalBudget;
        proposalImplementationAddress = proposal.proposalImplementationAddress;*/
        proposalBasicData.tags = proposal.tags;

 

    }

 /*   function getProposalResult(uint256 proposalId) public view returns (
    uint256 id,
    uint256 numberOfVotes,
    uint256 numberOfYesVotes,
    uint256 numberOfNoVotes,
    uint256 sumOfYesVotes,
    uint256 sumOfNoVotes,
    bool executed,
    bool passed,
    uint quorum,
    uint256 startTime,
    uint256 endTime,
    uint256 proposalBudget,
    address proposalImplementationAddress,
    string[] memory tags
) {
        IUtilityImpl.Proposal storage proposal = proposals[proposalId];
        
        id = proposal.id;
        numberOfVotes = proposal.numberOfVotes;
        numberOfYesVotes = proposal.numberOfYesVotes;
        numberOfNoVotes = proposal.numberOfNoVotes;
        sumOfYesVotes = proposal.sumOfYesVotes;
        sumOfNoVotes = proposal.sumOfNoVotes;
        executed = proposal.executed;
        passed = proposal.passed;
        quorum = proposal.quorum;
        startTime = proposal.startTime;
        endTime = proposal.endTime;
        proposalBudget = proposal.proposalBudget;
        proposalImplementationAddress = proposal.proposalImplementationAddress;
        tags = proposal.tags;
    }*/



    function transferVoteCost(Vote memory voteData, uint cost) public returns (bool result) {
        // Perform the necessary logic here
        // You can use the provided voteData and cost parameters to implement the transfer

        // Return the result of the transfer
        return true;
    }
        function getVotingStructuresById()
        public
        view
        returns (uint[] memory, VotingStructure[] memory)
    {    uint[] memory keys = new uint[](NUMBEROFVOTINGSTRUCTURES);
        VotingStructure[] memory values = new VotingStructure[](NUMBEROFVOTINGSTRUCTURES);

        uint index = 0;
        for (uint i = 0; i < NUMBEROFVOTINGSTRUCTURES; i++) {
                keys[index] = i+1;
                values[index] = votingStructureIdVotingStructure[i];
                index++;
        }

        return (keys, values);
    }
    function vote(Vote calldata voteData, uint communityId) public onlyThroughAllowedCommunities {
        Proposal storage proposal = proposals[voteData.proposalId];

        (uint[] memory votingStructureKeys, VotingStructure[] memory votingStructureValues) = getVotingStructuresById();
      
        VotingStructure memory votingStructure = votingStructureValues[proposal.votingStructureId];
        require(voteData.numericValue  >= votingStructure.lowerLimit, "Voting value can not be lower than the predefined limit.");
        require(voteData.numericValue  <= votingStructure.upperLimit, "Voting value can not be higher than the predefined limit.");

        // Check if the voter has not already voted on this proposal
        bytes32 voterHash = keccak256(
            abi.encodePacked(voteData.voterAddress, voteData.voterChainId,voteData.proposalId)
        );
        require(proposal.voted[voterHash] == 0, "Already voted for this proposal.");

        // Check if the proposal is open for voting
        require(
            block.timestamp >= proposal.startTime &&
                block.timestamp <= proposal.endTime,
            "Voting not open."
        );
        //We need to get the cost for the votes based on voting cost
        VoteCostType voteCostType = votingStructure.voteCostType;
        require(voteCostType == VoteCostType.Free ||
        ((voteCostType == VoteCostType.OneTokenPerVote) && transferVoteCost(voteData, 1)) ||
        (voteCostType == VoteCostType.SameAsVoteAmount && transferVoteCost(voteData, voteData.numericValue)) ||
        (voteCostType == VoteCostType.Quadratic && transferVoteCost(voteData, voteData.numericValue * voteData.numericValue)),
        "Caller is not eligible to pay for the vote cost based on the selected scheme for this proposal."
    );

        // Record the vote
        proposal.numberOfVotes += 1;
        proposal.votes[voterHash] = voteData;
        if (voteData.yesno){
            proposal.numberOfYesVotes += 1;
            proposal.sumOfYesVotes += voteData.numericValue;
        }else{
            proposal.numberOfNoVotes += 1;
            proposal.sumOfNoVotes += voteData.numericValue;
        }
        proposal.executed = false;
        proposal.passed = false;
    }



    function executeProposal(uint256 proposalIndex) public {
        Proposal storage proposal = proposals[proposalIndex];
        address proposalContractAddress = proposal.proposalImplementationAddress;
        
        // Check if the proposal has not already been executed
        require(!proposal.executed, "Already executed.");
        require(proposalContractAddress != address(0), "There is no associated Proposal Contract to Execute.");
        // Check if the proposal has enough support
        /*require(
            proposal.forVotes > proposal.againstVotes,
            "Proposal did not pass."
        );*/

        // Execute the proposal
        //IProposalActionContract proposalActionContract = ProposalActionContract(payable(address(proposalContractAddress)));
        proposal.executed = true;

        // Do something with the proposal
    }

    //function _authorizeUpgrade(
    //    address newImplementation
    //) internal virtual  {}
}