from iconservice import *
from .IRC3 import IRC3

class IRC3Burnable(IRC3):
    '''
    Implementation of IRC3Burnable
    '''

    @external
    def burn(self, _from: Address, _tokenId: int):
        super()._burn(_from, _tokenId)
