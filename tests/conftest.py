import boa
import pytest

from typing import Any, Callable, List

@pytest.fixture(scope="session")
def accounts() -> List[Any]:
    return [boa.env.generate_address() for _ in range(11)]

@pytest.fixture(scope="session")
def account(accounts) -> Any:
    return accounts[0]

@pytest.fixture(scope="session")
def token(account):
    with boa.env.prank(account):
        return boa.load('src/mocks/mock_erc20.vy', "Test Token", "TEST", 18)

@pytest.fixture(scope="session")
def nft(account):
    with boa.env.prank(account):
        return boa.load('src/nft.vy', "ENNEFFTEE", "TEST", "https://bophades.nutz", "ENEFFTEE", "1")

@pytest.fixture(scope="session")
def auction_house(account, token, nft):
    with boa.env.prank(account):
        return boa.load('src/auction.vy', token.address, nft.address)

