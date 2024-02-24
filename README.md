# Saturn Series Auction House Contracts

A simple auction house implemented in pure Vyper, as well as a standard ERC721 which can be auctioned off in exchange for a specific ERC20 token

<p align="center">
  <img src="./auctionhouse.gif" height="512" />
</p>

## NFT Contract

The NFT is a simple fork of snekmate's ERC721, for the primary reason that is well-maintained, tested, and built

```py
@external
def safe_mint(owner: address, uri: String[432]):
```

The function `safe_mint` will allow you to mint a token to yourself (putting your own address as owner) with a specific uri, which should point to the gif/png you prefer for the NFT itself.

## Main Functions of the Auction House Contract
Every auction is understood in terms of a `lot`, which is the `tokenId` of the NFT which is up for sale. The owner of the auction house is the address who deployed it, but this can be changed at any time. They specify the NFT and ERC20 token address that will be linked to the auction house at the time of deployment.

```py
@external
def start(lot: uint256, patron: address):
```

Only the owner may start the auction, they simply approve the auctionhouse, and then call with the `tokenId` of the nft they wish to auction as the `lot`, and the address of the beneficiary of the auction as the `patron`; this address will receive the proceeds of the auction minus the fees.

```py
@external
def bid(bid: uint256, lot: uint256):
```

Anyone may bid in ERC20 tokens, specifying their amount in `bid`, and for which nft they are bidding on via `lot`. Note: This does mean the Auction House can handle multiple concurrent lots.

```py
@external
def end(lot: uint256):
```

Finally, anyone can resolve the auction, calling `end` which sends the nft to the winner of the auction.

## Ownership

The owner of the auction can withdraw all erc20 fees generated via 

```py
@external
def withdraw_proceeds(benefactor: address):
```

which will send all proceeds to the address they specify, and can only be called by the owner.
