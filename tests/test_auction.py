import boa
import pytest

def test_auction_house(account, accounts, auction_house, nft, token):
    """
        Test to sample bidding, and an eventual settlement of the auction
    """
    token.mint(account, 1000 * 10 ** 18, sender=account)
    token.approve(auction_house.address, 1000 * 10 ** 18, sender=account)

    nft.safe_mint(account, "http://memes.org", sender=account)
    id = nft._counter()-1

    assert nft.ownerOf(id) == account

    nft.approve(auction_house.address, id, sender=account)
    auction_house.start(id, sender=account)

    bidder, bid = auction_house.topBid(id)

    assert bid == 500 * 10 ** 18
    assert bidder == '0x0000000000000000000000000000000000000000'

    auction_house.bid(750 * 10 ** 18, id, sender=account)

    assert token.balanceOf(account) == 250 * 10 ** 18
    assert token.balanceOf(auction_house) == 750 * 10 ** 18
    
    bidder, bid = auction_house.topBid(id)

    assert bid == 750 * 10 ** 18
    assert bidder == account

    account_two = accounts[2]

    token.mint(account_two, 1000 * 10 ** 18, sender=account_two)
    token.approve(auction_house.address, 1000 * 10 ** 18, sender=account_two)

    auction_house.bid(1000 * 10 ** 18, id, sender=account_two)

    assert token.balanceOf(account_two) == 0
    assert token.balanceOf(account) == 1000 * 10 ** 18
    assert token.balanceOf(auction_house) == 1000 * 10 ** 18
    
    bidder, bid = auction_house.topBid(id)

    assert bid == 1000 * 10 ** 18
    assert bidder == account_two

    boa.env.time_travel(86400 * 365)

    auction_house.end(id, sender=account)

    assert nft.ownerOf(id) == account_two
