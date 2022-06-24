// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NFT is ERC721URIStorage {

    using Counters for Counters.Counter;
    Counters.Counter public tokenCount;

    mapping(uint256 => address) public tokenCountToCreator;

    constructor() ERC721("Pankaj", "PANK") {}

    function mint(string memory _tokenURI) external returns (uint256) {
        tokenCount.increment();
        uint _tokenCount = tokenCount.current();
        _safeMint(msg.sender, _tokenCount);
        _setTokenURI(_tokenCount, _tokenURI);
        tokenCountToCreator[_tokenCount] = msg.sender;
        return (_tokenCount);
    }
}
