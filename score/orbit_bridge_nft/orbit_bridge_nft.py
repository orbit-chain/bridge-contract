from iconservice import *
from .contracts.tokens.IRC3Burnable import IRC3Burnable
from .contracts.tokens.IRC3Mintable import IRC3Mintable
from .contracts.tokens.IRC3Updatable import IRC3Updatable

TAG = 'OrbitBridgeNFT'

class OrbitBridgeNFT(IRC3Burnable, IRC3Mintable, IRC3Updatable):
    pass
