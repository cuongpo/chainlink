// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

import '@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol';
import '@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol';
import '@chainlink/contracts/src/v0.8/ConfirmedOwner.sol';
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./nft.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

contract VRFv2Consumer is VRFConsumerBaseV2, ConfirmedOwner {
    IERC20 public immutable mainToken;
    address public nftContract; 
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
        uint collectionId;
        address requester;
    }

    mapping (uint256 => uint256) public boxPrice;
    mapping (uint256 => uint256) public numberOfTokenInBox;
    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 1;

    /**
     * HARDCODED FOR GOERLI
     * COORDINATOR: 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D
     */
    constructor(address _Token,uint64 subscriptionId,address nftAddress_)
        VRFConsumerBaseV2(0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed);
        s_subscriptionId = subscriptionId;
        nftContract = nftAddress_;
        mainToken = IERC20(_Token);
    }


    // Assumes the subscription is funded sufficiently.
    function requestRandomWords(uint _collectionId) external returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        // check enough balance

        // transfer money
        mainToken.transferFrom(msg.sender,nftcontract(nftContract).getCollectionOwner(_collectionId),boxPrice[_collectionId]);
        s_requests[requestId] = RequestStatus({randomWords: new uint256[](0), exists: true, fulfilled: false, collectionId: _collectionId, requester: msg.sender});
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(s_requests[_requestId].exists, 'request not found');
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        // transfer nft to owner
        uint x = (s_requests[_requestId].randomWords[0]) % numberOfTokenInBox[s_requests[_requestId].collectionId];

        nftcontract(nftContract).transferFrom(address(this),s_requests[_requestId].requester, x+1); 
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(uint256 _requestId) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, 'request not found');
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    function getRandomWord(uint256 _requestId) public view returns(uint256[] memory randomWords) {
        return s_requests[_requestId].randomWords;
    }
    
    function buyBox (uint256 _collectionId) external {
        // transfer money from msg.sender to contract
        mainToken.transferFrom(msg.sender,address(this),boxPrice[_collectionId]);
        // get randomworld. msg.sender linked
 
    }
    
    
    function createBox(uint256 _collectionId, uint256 _price) external  {
        // require colection owner 
        require(nftcontract(nftContract).getCollectionOwner(_collectionId) == msg.sender,"not collection owner");
        // price > 0
        require(_price > 0, "price greater than zero");
        boxPrice[_collectionId] = _price;
    }

    function addTokenToBox (uint256 tokenId_,uint256 _collectionId) external {
        require(
            nftcontract(nftContract).ownerOf(tokenId_) == msg.sender,
            "sender is not owner of token"
        );
        require(
            nftcontract(nftContract).getApproved(tokenId_) == address(this) ||
                nftcontract(nftContract).isApprovedForAll(msg.sender, address(this)),
            "The contract is unauthorized to manage this token"
        );
        require(
            nftcontract(nftContract).getCollectionId(tokenId_) == _collectionId,
            "Collection Id is not match"
        );
        nftcontract(nftContract).transferFrom(msg.sender, address(this), tokenId_);
        numberOfTokenInBox[_collectionId] = numberOfTokenInBox[_collectionId] + 1; 
    }




}
