from iconservice import *
from .contracts.tokens.IRC2burnable import IRC2Burnable
from .contracts.tokens.IRC2mintable import IRC2Mintable

TAG = 'OrbitBridgeToken'

class OrbitBridgeToken(IRC2Burnable, IRC2Mintable):
    pass
