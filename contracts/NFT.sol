// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NFT is ERC721URIStorage {
    uint public tokenCount;

    mapping(address => uint) public creatorToTokenCount;

    constructor() ERC721("Pankaj", "PANK"){}

    function mint(string memory _tokenURI) external returns(uint) {
        tokenCount++;
        _safeMint(msg.sender, tokenCount);
        _setTokenURI(tokenCount, _tokenURI);
        creatorToTokenCount[msg.sender] = tokenCount;
        return(tokenCount);
    }
}