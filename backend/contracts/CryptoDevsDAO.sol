// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Interface for the FakeNFTMarketplace
 */
interface IFakeNFTMarketplace {
    /// @dev getPrice() returns the price of an NFT from the FakeNFTMarketplace
    /// @return Returns the price in Wei for an NFT
    function getPrice() external view returns (uint256);

    /// @dev available() returns whether or not the given _tokenId has already been purchased
    /// @return Returns a boolean value - true if available, false if not
    function available(uint256 _tokenId) external view returns (bool);

    /// @dev purchase() purchases an NFT from the FakeNFTMarketplace
    /// @param _tokenId - the fake NFT tokenID to purchase
    function purchase(uint256 _tokenId) external payable;
}

/**
 * Minimal interface for CryptoDevsNFT containing only two functions
 * that we are interested in
 */
interface ICryptoDevsNFT {
    /// @dev balanceOf returns the number of NFTs owned by the given address
    /// @param owner - address to fetch number of NFTs for
    /// @return Returns the number of NFTs owned
    function balanceOf(address owner) external view returns (uint256);

    /// @dev tokenOfOwnerByIndex returns a tokenID at given index for owner
    /// @param owner - address to fetch the NFT TokenID for
    /// @param index - index of NFT in owned tokens array to fetch
    /// @return Returns the TokenID of the NFT
    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);
}

contract CryptoDevsDAO is Ownable {
    struct Proposal {
        uint256 nftTokenId; // the tokenID of the NFT to purchase from FakeNFTMarketplace if the proposal passes
        uint256 deadline; // the UNIX timestamp until which this proposal is active. Proposal can be executed after the deadline has been exceeded.
        uint256 yayVotes; // number of yay votes for this proposal
        uint256 nayVotes; // number of nay votes for this proposal
        bool executed; // whether or not this proposal has been executed yet. Cannot be executed before the deadline has been exceeded.
        mapping(uint256 => bool) voters; // mapping of voter addresses to whether or not they have voted on this proposal
    }

    // Create an enum named Vote containing possible options for a vote
    enum Vote {
        YAY, // YAY = 0
        NAY // NAY = 1
    }

    mapping(uint256 => Proposal) public proposals; // mapping of proposal IDs to Proposal structs
    uint256 public numProposals;

    IFakeNFTMarketplace nftMarketplace;
    ICryptoDevsNFT cryptoDevsNFT;

    // Create a payable constructor which initializes the contract
    // instances for FakeNFTMarketplace and CryptoDevsNFT
    // The payable allows this constructor to accept an ETH deposit when it is being deployed
    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    // Create a modifier which only allows a function to be
    // called by someone who owns at least 1 CryptoDevsNFT
    modifier nftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT_A_DAO_MEMBER");
        _;
    }

    // Create a modifier which only allows a function to be
    // called if the given proposal's deadline has not been exceeded yet
    modifier activeProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline > block.timestamp,
            "DEADLINE_EXCEED"
        );
        _;
    }

    // Create a modifier which only allows a function to be
    // called if the given proposals' deadline HAS been exceeded
    // and if the proposal has not yet been executed
    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline < block.timestamp,
            "DEADLINE_NOT_EXCEED"
        );
        require(
            proposals[proposalIndex].executed == false,
            "PROPOSAL_ALREADY_EXECUTED"
        );
        _;
    }

    function createProposal(uint256 _nftTokenIds)
        external
        nftHolderOnly
        returns (uint256)
    {
        require(nftMarketplace.available(_nftTokenIds), "NFT_NOT_FOR_SALE");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenIds;
        proposal.deadline = block.timestamp + 5 minutes;
        numProposals++;

        return numProposals - 1;
    }

    /// @dev voteOnProposal allows a CryptoDevsNFT holder to cast their vote on an active proposal
    /// @param _proposalIndex - the index of the proposal to vote on in the proposals array
    /// @param vote - the type of vote they want to cast
    function voteOnProposal(uint256 _proposalIndex, Vote vote)
        external
        nftHolderOnly
        activeProposalOnly(_proposalIndex)
    {
        Proposal storage proposal = proposals[_proposalIndex];

        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        // Calculate how many NFTs are owned by the voter
        // that haven't already been used for voting on this proposal
        for (uint256 i; i < voterNFTBalance; i++) {
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false) {
                proposal.voters[tokenId] = true;
                numVotes++;
            }
        }

        require(numVotes > 0, "ALREADY_VOTED");

        if (vote == Vote.YAY) {
            proposal.yayVotes += numVotes;
        } else {
            proposal.nayVotes += numVotes;
        }
    }

    /// @dev executeProposal allows any CryptoDevsNFT holder to execute a proposal after it's deadline has been exceeded
    /// @param _proposalIndex - the index of the proposal to execute in the proposals array
    function executeProposal(uint256 _proposalIndex)
        external
        nftHolderOnly
        inactiveProposalOnly(_proposalIndex)
    {
        Proposal storage proposal = proposals[_proposalIndex];

        if (proposal.yayVotes > proposal.nayVotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance > nftPrice, "NOT_ENOUGH_FUNDS");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }

    /// @dev withdrawEther allows the contract owner (deployer) to withdraw the ETH from the contract
    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "Nothing to withdraw; contract balance empty");
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    // The following two functions allow the contract to accept ETH deposits
    // directly from a wallet without calling a function
    receive() external payable {}

    fallback() external payable {}
}
