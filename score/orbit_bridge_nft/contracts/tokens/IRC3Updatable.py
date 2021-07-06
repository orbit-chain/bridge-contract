from iconservice import *
from .IRC3 import IRC3

class IRC3Updatable(IRC3):
    '''
    Implementation of IRC3Updatable
    '''

    @external
    def update(self, _tokenId: int, _name: str, _others: str):
        super()._update(_tokenId, _name, _others)
