from iconservice import *
from .IRC3 import IRC3

class IRC3Mintable(IRC3):
    '''
    Implementation of IRC3Mintable
    '''

    @external
    def mint(self, _to: Address, _tokenId: int):
        super()._mint(_to, _tokenId)
