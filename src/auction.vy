# @version 0.3.10

"""
@title Saturn Series's Auction House
@license GNU Affero General Public License v3.0
@notice Simple NFT Auction Implemented in Vyper
"""

from vyper.interfaces import ERC20
from vyper.interfaces import ERC721
interface NftContract:
    def safe_mint(owner: address, uri: String[176]) -> uint256: nonpayable




# Protocol settings variables
auction_duration: public(uint256) # Duration of auctions, default 5 days
minimum_bid_increment_percentage: public(uint256)  # Minimum bid increment
extension_time_seconds: public(uint256)  # Time added to auction if a bid is made near end
starting_bid: public(uint256)  # Starting bid for auctions
MAX_FEE_PERCENTAGE: constant(uint256) = 100_000  # Max fee percentage basis points
PERCENTAGE_SCALAR: constant(uint256) = 100_000  # Scalar to maintain precision in percentages
fee: public(uint256)  # Fee percentage of the auction house
bid_token: public(immutable(ERC20))  # ERC20 token used for bidding
nft: public(immutable(ERC721))  # ERC721 token that represents the NFTs

# ///////////////////////////////////////////////////// #
#                     Admin Functions                   #
# ///////////////////////////////////////////////////// #
# @dev Returns the address of the current owner.
owner: public(address)
# @dev Returns the address of the current auctioneer.
auctioneer: public(address)

# @dev Emitted when the ownership is transferred
# from `previous_owner` to `new_owner`.
event OwnershipTransferred:
    previous_owner: indexed(address)
    new_owner: indexed(address)



event AuctioneerChanged:
    previous_auctioneer: indexed(address)
    new_auctioneer: indexed(address)



@external
def change_auction_duration(new_duration: uint256):
    """
    @dev Changes the duration of the auction.
    @param new_duration The new duration of the auction.
    """
    self._check_owner()
    self.auction_duration = new_duration

@external
def change_sniping_timer(new_timer: uint256):
    """
    @dev Changes the time added to an auction if a bid is made near its end.
    @notice Can only be called by the contract owner.
    @param new_timer The new extension time in seconds.
    """
    self._check_owner()
    assert new_timer > 0 and new_timer <= 86400, "Invalid timer: must be between 1 second and 24 hours"
    self.extension_time_seconds = new_timer

@external
def change_minimum_bid_increment_percentage(new_percentage: uint256):
    self._check_owner()
    self.minimum_bid_increment_percentage = new_percentage

@external
def change_extension_time_seconds(new_extension_time: uint256):
    self._check_owner()
    self.extension_time_seconds = new_extension_time

@external
def change_starting_bid(new_starting_bid: uint256):
    self._check_owner()
    self.starting_bid = new_starting_bid


@external
def change_fee(new_fee: uint256):
    """
    @dev Changes the fee of the auction.
    @param new_fee The new fee of the auction.
    """
    self._check_owner()
    assert new_fee < MAX_FEE_PERCENTAGE, "Fee must be less than 100%"
    self.fee = new_fee

@external
def transfer_ownership(new_owner: address):
    """
    @dev Transfers the ownership of the contract
         to a new account `new_owner`.
    @param new_owner The 20-byte address of the new owner.
    """
    self._check_owner()
    assert new_owner != empty(address), "Ownable: new owner is the zero address"
    self._transfer_ownership(new_owner)

@external
def set_auctioneer(new_auctioneer: address):
    """
    @dev Assigns the auctioneer role to a new account.
    @param new_auctioneer The address to assign the auctioneer role to.
    """
    self._check_owner()
    assert new_auctioneer != empty(address), "Auctioneer: new auctioneer is the zero address"
    old_auctioneer: address = self.auctioneer
    self.auctioneer = new_auctioneer
    log AuctioneerChanged(old_auctioneer, new_auctioneer)

@internal
def _check_owner():
    assert msg.sender == self.owner, "Ownable: caller is not the owner"

@internal
def _check_auctioneer():
    """
    @dev Checks if the message sender is the auctioneer.
    """
    assert msg.sender == self.auctioneer, "Caller is not the auctioneer"

@internal
def _check_owner_or_auctioneer():
    """
    @dev Checks if the message sender is either the owner or the auctioneer.
    """
    assert msg.sender == self.owner or msg.sender == self.auctioneer, \
           "Caller is not the owner or the auctioneer"


@internal
def _transfer_ownership(new_owner: address):
    """
    @dev Transfers the ownership of the contract
         to a new account `new_owner`.
    @param new_owner The address of the new owner.
    """
    old_owner: address = self.owner
    self.owner = new_owner
    log OwnershipTransferred(old_owner, new_owner)



# ///////////////////////////////////////////////////// #
#                  Auction House Logic                  #
# ///////////////////////////////////////////////////// #



event AuctionStarted:
    lot: indexed(uint256)
    patron: indexed(address)
    end_date: uint256

event AuctionEnded:
    lot: indexed(uint256)
    winner: indexed(address)
    proceeds: uint256

event BidSubmitted:
    lot: indexed(uint256)
    bidder: indexed(address)
    bid: uint256
    new_end_date: uint256


topBid: public(HashMap[uint256, Bid])
patron: public(HashMap[uint256, address])
auction_ends: public(HashMap[uint256, uint256])



protocol_fee: public(uint256)

struct Bid:
        bidder: address
        bid: uint256

@external
def __init__(_token: ERC20, _nft: ERC721, _fee: uint256):
    """
    @param _token The address of the ERC20 token to use for the auction.
    @param _nft The address of the ERC721 token to auction.
    @param _fee The percentage of the winning bid to take as a fee for the dao 
    """
    bid_token = _token
    nft = _nft

    self._transfer_ownership(msg.sender)
    self.fee = _fee
    self.auction_duration =  432_000  # default 5 days
    self.extension_time_seconds = 3600  # default 1 hour



@external
def mint_and_start_auction(uri: String[176], patron: address, nft_contract: NftContract):
    """
    @dev Mints a new NFT and starts an auction for it.
    @param uri The URI for the NFT to be minted.
    @param patron The address of the patron for whom the auction is being started.
    @param nft_contract The address of the NFT contract with minting capability.
    """
    self._check_owner_or_auctioneer()
    token_id: uint256 = nft_contract.safe_mint(self,uri)  # Mint directly to the auction contract

    assert self.auction_ends[token_id] == 0, "Auction is still in progress"
    self._initialize_auction(token_id, patron)


@external
def start_auction(lot: uint256, patron: address):
    """
    @dev Starts an auction for a lot, transferring the NFT to this contract.
    @param lot The tokenID of the NFT to start an auction for.
    @param patron The address of the patron whom the auctioneer is starting the auction for.
    """
    self._check_owner_or_auctioneer()
    assert self.auction_ends[lot] == 0, "Auction is still in progress"
    nft.transferFrom(msg.sender, self, lot)
    self._initialize_auction(lot, patron)

@external
def start_auction_with_auctionhouse_held_nft(lot: uint256, patron: address):
    """
    @dev Starts an auction for a lot already held by the auction house.
    @param lot The tokenID of the NFT to start an auction for.
    @param patron The address of the patron whom the auctioneer is starting the auction for.
    """
    self._check_owner_or_auctioneer()
    assert self.auction_ends[lot] == 0, "Auction is ongoing"
    assert nft.ownerOf(lot) == self, "Auction House must own the NFT to start an auction."
    self._initialize_auction(lot, patron)

@internal
def _initialize_auction(lot: uint256, patron: address):
    """
    @dev Initializes  an auction by setting the conditions common to both auction types.
    @param lot The token ID of the NFT to auction.
    @param patron The address initiating the auction.
    """
    self.auction_ends[lot] = block.timestamp + self.auction_duration
    self.patron[lot] = patron
    self.topBid[lot] = Bid({
        bidder: empty(address),
        bid: self.starting_bid
    })
    log AuctionStarted(lot, patron, self.auction_ends[lot])


@external
def bid(bid: uint256, lot: uint256):
    """
    @dev Places a bid for a lot.
    @param bid The amount of ERC20 tokens to bid.
    @param lot The ID of the lot to bid on.
    """
    assert bid > (self.topBid[lot].bid * 105) / 100, "LOW BID"
    max_time: uint256 = self.auction_ends[lot]
    assert block.timestamp < max_time, "AUCTION FINISHED"
    if (max_time - block.timestamp) < self.extension_time_seconds:
        self.auction_ends[lot] += self.extension_time_seconds

    bid_token.transferFrom(msg.sender, self, bid)

    if self.topBid[lot].bidder != empty(address):
        bid_token.transfer(self.topBid[lot].bidder, self.topBid[lot].bid)

    self.topBid[lot] = Bid({bidder: msg.sender, bid: bid})

    log BidSubmitted(lot, msg.sender, bid, self.auction_ends[lot])


@external
def end(lot: uint256):
    """
    @dev Ends the auction and transfers the NFT to the highest bidder.
    @param lot The ID of the lot to close the auction for.
    """

    assert block.timestamp >= self.auction_ends[lot], "AUCTION NOT FINISHED"
    winningBid: Bid = self.topBid[lot]

    if winningBid.bidder != empty(address):
        # There was at least one bid higher than the starting bid
        fee: uint256 = (winningBid.bid * self.fee) / PERCENTAGE_SCALAR
        patron_proceeds: uint256 = winningBid.bid - fee
        self.protocol_fee += fee

        bid_token.transfer(self.patron[lot], patron_proceeds)
        nft.transferFrom(self, winningBid.bidder, lot)


        log AuctionEnded(lot, winningBid.bidder, patron_proceeds)
    else:

        self.auction_ends[lot] = 0
    
        log AuctionEnded(lot, self.owner, 0)


@external
def withdraw_proceeds(benefactor: address):
    """
    @dev Withdraws the fees generated from the auctions.
    """
    self._check_owner()
    bid_token.transfer(benefactor, self.protocol_fee)
    self.protocol_fee = 0
