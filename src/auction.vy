# @version 0.3.10

"""
@title Cassini's Auction House
@license GNU Affero General Public License v3.0
@notice Simple NFT Auction Implemented in Vyper
"""

from vyper.interfaces import ERC20
from vyper.interfaces import ERC721

# ///////////////////////////////////////////////////// #
#                     Ownership                         #
# ///////////////////////////////////////////////////// #
# @dev Returns the address of the current owner.
owner: public(address)

# @dev Emitted when the ownership is transferred
# from `previous_owner` to `new_owner`.
event OwnershipTransferred:
    previous_owner: indexed(address)
    new_owner: indexed(address)


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

@internal
def _check_owner():
    assert msg.sender == self.owner, "Ownable: caller is not the owner"


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


event AuctionEnded:
    lot: indexed(uint256)
    winner: indexed(address)


event BidSubmitted:
    lot: indexed(uint256)
    bidder: indexed(address)
    bid: uint256


bid_token: public(immutable(ERC20))
nft: public(immutable(ERC721))

topBid: public(HashMap[uint256, Bid])
patron: public(HashMap[uint256, address])
auction_ends: public(HashMap[uint256, uint256])

auction_duration: public(uint256)

fee: public(uint256)

profit: public(uint256)


struct Bid:
        bidder: address
        bid: uint256

@external
def change_duration(new_duration: uint256):
    """
    @dev Changes the duration of the auction.
    @param new_duration The new duration of the auction.
    """
    assert msg.sender == self.owner, "NOT OWNER"
    self.auction_duration = new_duration

@external
def change_fee(new_fee: uint256):
    """
    @dev Changes the fee of the auction.
    @param new_fee The new fee of the auction.
    """
    assert msg.sender == self.owner, "NOT OWNER"
    assert new_fee < 1000, "Fee must be less than 100%"
    self.fee = new_fee

@external
def __init__(_token: ERC20, _nft: ERC721, _fee: uint256):
    """
    @param _token The address of the ERC20 token to use for the auction.
    @param _nft The address of the ERC721 token to auction.
    @param _fee The percentage of the winning bid to take as a fee for the dao, as 
    """
    bid_token = _token
    nft = _nft

    self._transfer_ownership(msg.sender)
    self.fee = _fee
    self.auction_duration = 86400 * 5


@external
def start(lot: uint256, patron: address):
    """
    @dev Starts an auction for a lot.
    @param lot The tokenID of the nft to start an auction for.
    """
    assert msg.sender == self.owner, "NOT OWNER"
    nft.transferFrom(msg.sender, self, lot)

    self.auction_ends[lot] = block.timestamp + self.auction_duration

    self.patron[lot] = patron
    self.topBid[lot] = Bid(
        {
            bidder: empty(address),
            # 500 Tokens is the starting bid
            bid: 500 * 10**18,
        }
    )

    log AuctionStarted(lot, patron)


@external
def bid(bid: uint256, lot: uint256):
    """
    @dev Places a bid for a lot.
    @param bid The amount of ERC20 tokens to bid.
    @param lot The ID of the lot to bid on.
    """
    assert bid > (self.topBid[lot].bid * 105) / 100, "LO BID"
    max_time: uint256 = self.auction_ends[lot]
    assert block.timestamp < max_time, "OVER"  # FIX Comment
    if (max_time - block.timestamp) < 3600:
        self.auction_ends[lot] += 3600

    bid_token.transferFrom(msg.sender, self, bid)

    if self.topBid[lot].bidder != empty(address):
        bid_token.transfer(self.topBid[lot].bidder, self.topBid[lot].bid)

    self.topBid[lot] = Bid({bidder: msg.sender, bid: bid})

    log BidSubmitted(lot, msg.sender, bid)


@external
def end(lot: uint256):
    """
    @dev Ends the auction and transfers the NFT to the highest bidder.
    @param lot The ID of the lot to close the auction for.
    """
    assert block.timestamp >= self.auction_ends[lot]
    winningBid: Bid = self.topBid[lot]

    fee: uint256 = (winningBid.bid * self.fee) / 1000
    patron_proceeds: uint256 = winningBid.bid - fee
    self.profit += fee

    bid_token.transfer(self.patron[lot], patron_proceeds)
    nft.transferFrom(self, winningBid.bidder, lot)

    log AuctionEnded(lot, winningBid.bidder)


@external
def withdraw_proceeds(benefactor: address):
    """
    @dev Withdraws the proceeds from the auction.
    """
    assert msg.sender == self.owner
    bid_token.transfer(benefactor, self.profit)
    self.profit = 0
