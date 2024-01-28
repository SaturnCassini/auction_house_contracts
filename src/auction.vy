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


@external
def renounce_ownership():
  """
  @dev Leaves the contract without an owner.
  """
  self._check_owner()
  self._transfer_ownership(empty(address))


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

bid_token: public(immutable(ERC20))
nft: public(immutable(ERC721))

topBid: public(HashMap[uint256, Bid])
auction_ends: public(HashMap[uint256, uint256])

auction_duration: public(uint256)

profit: public(uint256)

struct Bid:
  bidder: address
  bid: uint256

@external
def __init__(_token: ERC20, _nft: ERC721):
  bid_token = _token
  nft = _nft
  self._transfer_ownership(msg.sender)

  self.auction_duration = 86400 * 5

@external
def start(lot: uint256):
  """
  @dev Starts an auction for a lot.
  @param lot The tokenID of the nft to start an auction for.
  """
  assert msg.sender == self.owner, "NOT OWNER"
  nft.transferFrom(msg.sender, self, lot)

  self.auction_ends[lot] = block.timestamp + self.auction_duration
  self.topBid[lot] = Bid({
    bidder: empty(address),
    # 500 Tokens is the starting bid
    bid: 500 * 10 ** 18
  })

@external
def bid(bid: uint256, lot: uint256):
  """
  @dev Places a bid for a lot.
  @param bid The amount of ERC20 tokens to bid.
  @param lot The ID of the lot to bid on.
  """
  assert bid > (self.topBid[lot].bid * 105) / 100, "LO BID"
  max_time: uint256 = self.auction_ends[lot]
  assert block.timestamp < max_time, "OVER"
  if (max_time - block.timestamp) < 3600:
    self.auction_ends[lot] += 3600
  
  bid_token.transferFrom(msg.sender, self, bid)
  
  if self.topBid[lot].bidder != empty(address):
    bid_token.transfer(self.topBid[lot].bidder, self.topBid[lot].bid)

  self.topBid[lot] = Bid({
    bidder: msg.sender,
    bid: bid
  })


@external
def end(lot: uint256):
  """
  @dev Ends the auction and transfers the NFT to the highest bidder.
  @param lot The ID of the lot to close the auction for.
  """
  assert block.timestamp >= self.auction_ends[lot]
  winningBid: Bid = self.topBid[lot]
  self.profit += winningBid.bid
  nft.transferFrom(self, winningBid.bidder, lot)

@external
def withdraw_proceeds(benefactor: address):
  """
  @dev Withdraws the proceeds from the auction.
  """
  assert msg.sender == self.owner
  bid_token.transfer(benefactor, self.profit)
  self.profit = 0