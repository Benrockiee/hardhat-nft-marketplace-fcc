// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Check out https://github.com/Fantom-foundation/Artion-Contracts/blob/5c90d2bc0401af6fb5abf35b860b762b31dfee02/contracts/FantomMarketplace.sol
// For a full decentralized nft marketplace

error PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error ItemNotForSale(address nftAddress, uint256 tokenId);
error NotListed(address nftAddress, uint256 tokenId);
error AlreadyListed(address nftAddress, uint256 tokenId);
error NoProceeds();
error NotOwner();
error NotApprovedForMarketplace();
error PriceMustBeAboveZero();

contract NftMarketplace is ReentrancyGuard {
    struct Listing {
        uint256 price;
        address seller;
    }

    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemCanceled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    /*mapping of NFT addresses mapped to a tokenId, mapped to listings 
    so back in our listing function, we update this listings */
    mapping(address => mapping(uint256 => Listing)) private s_listings;
    /* This mapping keeps track of how much money they make selling their NFTS*/
    mapping(address => uint256) private s_proceeds;

    /* To make sure we dont relist NFTS that are already listed, we 
       make this modidfier */
    modifier notListed(
        address nftAddress,
        uint256 tokenId,
        address owner
    ) {
        /*We make a new listing here & when we are done, we add it to 
        our list item function*/
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert AlreadyListed(nftAddress, tokenId);
        }
        _;
    }

    /* To make sure that buyItem is already listed,
       we make an isListed modifier */
    modifier isListed(address nftAddress, uint256 tokenId) {
        /*to check if this is listed we do: */
        Listing memory listing = s_listings[nftAddress][tokenId];
        /*we check the price*/
        if (listing.price <= 0) {
            revert NotListed(nftAddress, tokenId);
        }
        _;
    }
    /* To make sure that these listed NFTS are owned by the msg.sender,
       we make an isOwner modifier */
    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        /*We make this here & when we are done, we add it to 
        our list item function*/
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NotOwner();
        }
        _;
    }

    /////////////////////
    // Main Functions //
    /////////////////////
    /*
     * @notice Method for listing NFT
     * @param nftAddress Address of NFT contract
     * @param tokenId Token ID of NFT
     * @param price sale price for each item
     */
    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    )
        external
        /*notListed Modifier appended here*/
        notListed(nftAddress, tokenId, msg.sender)
        /*isOwner Modifier appended here*/
        isOwner(nftAddress, tokenId, msg.sender)
    {
        if (price <= 0) {
            revert PriceMustBeAboveZero();
        }

        /*In other for us to list this, we can do this in one or two ways
    1. We can send the NFTs to the contract & this would require a transfer and this
       means the contract holding the NFT.abi but this is Gas expensive and also 
       we will have the market hold our NFTand the user wont technically own it,
       infact they can, but they will have to withdraw it OR we can :

    2. owners can still hold their NFT and give the marketplace approval to sell
       the NFTS for them once their prices are met. so to make sure the marketPlace 
       has approval, we import /ERC721 from openzeppelin to use the approval function
       and we can call "getApproved" on that address.. 
       so now that we have this interface right here, we can say:
     /*/

        IERC721 nft = IERC721(nftAddress);
        /* If we are not approved, we revert */
        if (nft.getApproved(tokenId) != address(this)) {
            revert NotApprovedForMarketplace();
        }
        /* Now we probably wanna have some type of data structures 
        to list this NFT, if we use an array, anytime someone wants
        to buy an item, we have to traverse through it or make this
        massive dynamic array and it wouldnt be good as that gets
        really really big so we make this a MAPPING, its above */
        /* when we are done with that mapping, we update that s_listings mappings
       
          s_listings of the address, at the tokenId   */
        s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
        /* Since we are updating the mapping, its a good practice to 
         emit an event especially for this project and alson define
         at the top, SEE TOP */
        emit ItemListed(msg.sender, nftAddress, tokenId, price);
        /* To make sure we dont relist NFTS that are already listed, we 
       make a notListed modidfier, SEE TOP */
        /* To make sure that these listed NFTS are owned by the msg.sender,
       we make an isOwner modifier, SEE TOP */
    }

    /*
     * @notice Method for cancelling listing
     * @param nftAddress Address of NFT contract
     * @param tokenId Token ID of NFT
     */
    function cancelListing(address nftAddress, uint256 tokenId)
        external
        /* Only the owner of this NFT can cancel it */
        isOwner(nftAddress, tokenId, msg.sender)
        /* To make sure the NFT is actually listed */
        isListed(nftAddress, tokenId)
    {
        /* To cancel the listings(that mapping) we do: */
        delete (s_listings[nftAddress][tokenId]);
        /* We emit the event */
        emit ItemCanceled(msg.sender, nftAddress, tokenId);
    }

    /*
     * @notice Method for buying listing
     * @notice The owner of an NFT could unapprove the marketplace,
     * which would cause this function to fail
     * Ideally you'd also have a `createOffer` functionality.
     * @param nftAddress Address of NFT contract
     * @param tokenId Token ID of NFT
     */
    function buyItem(address nftAddress, uint256 tokenId)
        external
        payable
        isListed(nftAddress, tokenId)
        nonReentrant
    {
        /* To make sure that buyItem is already listed,
       we make an isListed modifier, SEE TOP */

        // Challenge - How would you refactor this contract to take:
        // 1. Abitrary tokens as payment? (HINT - Chainlink Price Feeds!)
        // 2. Be able to set prices in other currencies?
        // 3. Tweet me @PatrickAlphaC if you come up with a solution!
        Listing memory listedItem = s_listings[nftAddress][tokenId];
        //To make sure they are sending us enough money, we do:
        if (msg.value < listedItem.price) {
            revert PriceNotMet(nftAddress, tokenId, listedItem.price);
        }
        /* When somebody buys an item, this will update their proceeds*/
        /* We dont just send the seller money, we have them withdraw it,
         so we push the risk to them */

        s_proceeds[listedItem.seller] += msg.value;

        // https://fravoll.github.io/solidity-patterns/pull_over_push.html
        /* Once we buy this item, we delete the listings from the market place: */
        delete (s_listings[nftAddress][tokenId]);
        /*So we go ahead and transfer it */
        IERC721(nftAddress).safeTransferFrom(listedItem.seller, msg.sender, tokenId);
        /*Since we are updating a mapping, lets emit an event*/
        emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
    }

    /*
     * @notice Method for updating listing
     * @param nftAddress Address of NFT contract
     * @param tokenId Token ID of NFT
     * @param newPrice Price in Wei of the item
     */
    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice
    )
        external
        /* We make sure its listed */
        isListed(nftAddress, tokenId)
        nonReentrant
        isOwner(nftAddress, tokenId, msg.sender)
    {
        //We should check the value of `newPrice` and revert if it's below zero (like we also check in `listItem()`)
        if (newPrice <= 0) {
            revert PriceMustBeAboveZero();
        }
        /*To  update our listings */
        s_listings[nftAddress][tokenId].price = newPrice;
        /* We emit itemListed */
        emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
    }

    /*
     * @notice Method for withdrawing proceeds from sales
     */
    /*We are getting all the payments that we collected in buy item */
    function withdrawProceeds() external {
        uint256 proceeds = s_proceeds[msg.sender];
        if (proceeds <= 0) {
            revert NoProceeds();
        }
        /*We reset the proceeds to 0 */
        s_proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        require(success, "Transfer failed");
    }

    /////////////////////
    // Getter Functions //
    /////////////////////

    function getListing(address nftAddress, uint256 tokenId)
        external
        view
        returns (Listing memory)
    {
        return s_listings[nftAddress][tokenId];
    }

    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }
}

