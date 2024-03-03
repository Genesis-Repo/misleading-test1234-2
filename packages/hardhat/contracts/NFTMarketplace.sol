// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721Holder, Ownable {
    uint256 public feePercentage;   // Fee percentage to be set by the marketplace owner
    uint256 private constant PERCENTAGE_BASE = 100;

    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
        address currentBidder;
        uint256 currentBid;
        uint256 endTime;
    }

    mapping(address => mapping(uint256 => Listing)) private listings;

    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event NFTPriceChanged(address indexed seller, uint256 indexed tokenId, uint256 newPrice);
    event NFTUnlisted(address indexed seller, uint256 indexed tokenId);
    event AuctionStarted(address indexed seller, uint256 indexed tokenId, uint256 startingPrice, uint256 endTime);
    event NewBid(address indexed bidder, uint256 indexed tokenId, uint256 amount);
    event AuctionEnded(address indexed seller, address indexed winner, uint256 indexed tokenId, uint256 amount);

    constructor() {
        feePercentage = 2;  // Setting the default fee percentage to 2%
    }

    // Function to list an NFT for sale
    function listNFT(address nftContract, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");

        // Transfer the NFT from the seller to the marketplace contract
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        // Create a new listing
        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true,
            currentBidder: address(0),
            currentBid: 0,
            endTime: 0
        });

        emit NFTListed(msg.sender, tokenId, price);
    }

    // Function to start an auction for an NFT
    function startAuction(address nftContract, uint256 tokenId, uint256 startingPrice, uint256 duration) external {
        Listing storage listing = listings[nftContract][tokenId];
        require(listing.isActive, "NFT is not listed for sale");
        require(listing.seller == msg.sender, "You are not the seller");
        
        listing.price = startingPrice;
        listing.currentBid = startingPrice;
        listing.currentBidder = address(0);
        listing.endTime = block.timestamp + duration;

        emit AuctionStarted(msg.sender, tokenId, startingPrice, listing.endTime);
    }

    // Function to place a bid on an ongoing auction
    function placeBid(address nftContract, uint256 tokenId) external payable {
        Listing storage listing = listings[nftContract][tokenId];
        require(listing.isActive, "NFT auction is not active");
        require(block.timestamp < listing.endTime, "Auction has ended");
        require(msg.value > listing.currentBid, "Bid must be higher than current bid");

        if(listing.currentBidder != address(0)){
            payable(listing.currentBidder).transfer(listing.currentBid); // Refund previous bidder
        }

        listing.currentBidder = msg.sender;
        listing.currentBid = msg.value;

        emit NewBid(msg.sender, tokenId, msg.value);
    }

    // Function to end an ongoing auction and transfer NFT to the highest bidder
    function endAuction(address nftContract, uint256 tokenId) external {
        Listing storage listing = listings[nftContract][tokenId];
        require(listing.isActive, "NFT auction is not active");
        require(block.timestamp >= listing.endTime, "Auction has not ended yet");

        // Transfer the fee to the marketplace owner
        uint256 feeAmount = (listing.currentBid * feePercentage) / PERCENTAGE_BASE;
        uint256 sellerAmount = listing.currentBid - feeAmount;
        payable(owner()).transfer(feeAmount); // Transfer fee to marketplace owner
        
        // Transfer the remaining amount to the seller
        payable(listing.seller).transfer(sellerAmount);

        // Transfer the NFT to the highest bidder
        IERC721(nftContract).safeTransferFrom(address(this), listing.currentBidder, tokenId);

        // Update the listing
        listing.isActive = false;

        emit AuctionEnded(listing.seller, listing.currentBidder, tokenId, listing.currentBid);
    }

    // Other existing functions remain unchanged

    // Optional features that can be added:
    // 1. Escrow mechanism to hold funds until the buyer confirms receipt of the NFT
    // 2. Rating and review system for buyers and sellers
    // 3. Integration with external payment systems for multiple currency support
    // 4. Support for multiple NFT standards like ERC1155
    // 5. Ability to create curated collections or featured NFT listings
}