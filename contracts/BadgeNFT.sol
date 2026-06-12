// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BadgeNFT is ERC1155, Ownable {

    // Token ID sabitleri
    uint256 public constant WEEKLY_TOP10   = 0;
    uint256 public constant MONTHLY_TOP10  = 1;
    uint256 public constant SEASON_CHAMP   = 2;
    // 3+ → Achievement badge'leri

    // Yetkili mint edebilen adresler (AchievementManager, RewardPool)
    mapping(address => bool) public authorized;

    // Her adres her token'dan kaç tane mint etti (tekrar mint engeli)
    mapping(address => mapping(uint256 => bool)) public minted;

    string private _baseURI;

    event AuthorizedSet(address indexed account, bool status);
    event BadgeMinted(address indexed to, uint256 tokenId);

    constructor(string memory baseURI_) ERC1155(baseURI_) Ownable() {
        _baseURI = baseURI_;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    function setAuthorized(address account, bool status) external onlyOwner {
        authorized[account] = status;
        emit AuthorizedSet(account, status);
    }

    function mint(address to, uint256 tokenId) external onlyAuthorized {
        require(!minted[to][tokenId], "Already minted");
        minted[to][tokenId] = true;
        _mint(to, tokenId, 1, "");
        emit BadgeMinted(to, tokenId);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(_baseURI, "/", _toString(tokenId), ".json"));
    }

    function setBaseURI(string memory newURI) external onlyOwner {
        _baseURI = newURI;
        _setURI(newURI);
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
