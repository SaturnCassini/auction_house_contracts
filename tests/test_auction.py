import boa
import pytest

def test_auction_ownership(account, accounts, auction_house, nft, token):
    assert auction_house.nft() == nft.address
    assert auction_house.bid_token() == token.address
    assert auction_house.owner() == account
    assert auction_house.fee() == 50

    auction_house.transfer_ownership(accounts[4], sender=account)

    assert auction_house.owner() == accounts[4]
    
    with boa.reverts():
        auction_house.transfer_ownership(account, sender=account)

    with boa.reverts("Ownable: new owner is the zero address"):
        auction_house.transfer_ownership("0x0000000000000000000000000000000000000000" ,sender=accounts[4])

def test_auction_time(account, accounts, auction_house, nft, token):
    """
        Test to sample bidding, and an eventual settlement of the auction
    """
    token.mint(account, 1000 * 10 ** 18, sender=account)
    token.approve(auction_house.address, 1000 * 10 ** 18, sender=account)

    nft.safe_mint(account, "http://memes.org", sender=account)
    id = nft._counter()-1

    assert nft.ownerOf(id) == account

    nft.approve(auction_house.address, id, sender=account)
    auction_house.start(id, accounts[3], sender=account)
    
    boa.env.time_travel((86400 * 5) - (60 * 5))
    end_time = auction_house.auction_ends(id)

    auction_house.bid(750 * 10 ** 18, id, sender=account)
    end_time_ext = auction_house.auction_ends(id)

    assert end_time_ext > end_time

def test_admin_panel(account, accounts, auction_house, nft, token):
    auction_house.change_fee(100, sender=account)
    assert auction_house.fee() == 100

    with boa.reverts():
        auction_house.change_fee(101, sender=accounts[3])
                                 
    with boa.reverts():
        auction_house.change_fee(1000, sender=account)

    auction_house.change_duration(86400 * 7, sender=account)
    assert auction_house.auction_duration() == 86400 * 7

def test_patron_set_properly(accounts, auction_house, nft, token):
    for account in accounts:
        token.mint(account, 1000 * 10 ** 18, sender=accounts[0])
        token.approve(auction_house.address, 1000 * 10 ** 18, sender=accounts[0])

        nft.safe_mint(accounts[0], "http://memes.org", sender=accounts[0])
        id = nft._counter()-1
        nft.approve(auction_house.address, id, sender=accounts[0])
        auction_house.start(id, account, sender=accounts[0])

        assert auction_house.patron(id) == account


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
    auction_house.start(id, accounts[3], sender=account)

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
    assert token.balanceOf(accounts[3]) == (1000 * 10 ** 18) * 0.95

    assert token.balanceOf(auction_house.address) == (1000 * 10 ** 18) * 0.05
    assert token.balanceOf(auction_house.address) == auction_house.profit()

    auction_house.withdraw_proceeds(accounts[4], sender=account)

    assert token.balanceOf(accounts[4]) == (1000 * 10 ** 18) * 0.05
    assert token.balanceOf(auction_house.address) == 0