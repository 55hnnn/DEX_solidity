// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Dex {
    ERC20 tokenX;
    ERC20 tokenY;

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    constructor(address _tokenX, address _tokenY) {
        tokenX = ERC20(_tokenX);
        tokenY = ERC20(_tokenY);
    }

    function addLiquidity(uint256 amountX, uint256 amountY, uint256 minLiquidity) external returns (uint256) {
        require(amountX > 0 && amountY > 0, "Invalid token amounts");

        uint256 liquidityMinted;
        if (totalLiquidity == 0) {
            // 초기 유동성 공급
            liquidityMinted = amountX * amountY;
        } else {
            // 기존 유동성 공급 시, 현재 비율에 맞춰 유동성 토큰 계산
            uint256 liquidityX = (amountX * totalLiquidity) / tokenX.balanceOf(address(this));
            uint256 liquidityY = (amountY * totalLiquidity) / tokenY.balanceOf(address(this));
            liquidityMinted = liquidityX < liquidityY ? liquidityX : liquidityY;
        }

        require(liquidityMinted >= minLiquidity, "Insufficient liquidity minted");

        // 유동성 토큰 발행
        liquidity[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;

        require(tokenX.allowance(msg.sender, address(this)) >= amountX, "ERC20: insufficient allowance");
        require(tokenY.allowance(msg.sender, address(this)) >= amountY, "ERC20: insufficient allowance");

        require(tokenX.balanceOf(msg.sender) >= amountX, "ERC20: transfer amount exceeds balance");
        require(tokenY.balanceOf(msg.sender) >= amountY, "ERC20: transfer amount exceeds balance");

        // 토큰 전송 (사용자로부터 DEX 계약으로)
        require(tokenX.transferFrom(msg.sender, address(this), amountX), "Token X transfer failed");
        require(tokenY.transferFrom(msg.sender, address(this), amountY), "Token Y transfer failed");

        return liquidityMinted;
    }

    function removeLiquidity(uint256 amount, uint256 minAmountX, uint256 minAmountY) external returns (uint256, uint256) {
        require(amount > 0, "Invalid liquidity amount");
        require(liquidity[msg.sender] >= amount, "Insufficient liquidity");

        // 제거된 유동성에 비례하여 돌려줄 토큰 양 계산
        uint256 amountX = (amount * tokenX.balanceOf(address(this))) / totalLiquidity;
        uint256 amountY = (amount * tokenY.balanceOf(address(this))) / totalLiquidity;

        // 최소 요구량 확인
        require(amountX >= minAmountX, "Insufficient X amount");
        require(amountY >= minAmountY, "Insufficient Y amount");

        // 유동성 토큰 소각
        liquidity[msg.sender] -= amount;
        totalLiquidity -= amount;

        // 토큰 반환
        require(tokenX.transfer(msg.sender, amountX), "Token X transfer failed");
        require(tokenY.transfer(msg.sender, amountY), "Token Y transfer failed");

        return (amountX, amountY);
    }

    function swap(uint256 amountX, uint256 amountY, uint256 minOutput) external returns (uint256 output) {
        require((amountX > 0 && amountY == 0) || (amountX == 0 && amountY > 0), "Invalid input amounts");
        
        uint256 tokenXBalance = tokenX.balanceOf(address(this));
        uint256 tokenYBalance = tokenY.balanceOf(address(this));
        
        if (amountX > 0) {
            // x -> y
            uint256 newTokenXBalance = tokenXBalance + amountX;
            uint256 newTokenYBalance = (tokenXBalance * tokenYBalance) / newTokenXBalance;

            output = (tokenYBalance - newTokenYBalance) * 999 / 1000;

            require(output >= minOutput, "Insufficient output amount");
            require(tokenX.transferFrom(msg.sender, address(this), amountX), "Token X transfer failed");
            require(tokenY.transfer(msg.sender, output), "Token Y transfer failed");
        } 
        else {
            // y -> x
            uint256 newTokenYBalance = tokenYBalance + amountY;
            uint256 newTokenXBalance = (tokenXBalance * tokenYBalance) / newTokenYBalance;

            output = (tokenXBalance - newTokenXBalance) * 999 / 1000;

            require(output >= minOutput, "Insufficient output amount");
            require(tokenY.transferFrom(msg.sender, address(this), amountY), "Token Y transfer failed");
            require(tokenX.transfer(msg.sender, output), "Token X transfer failed");
        }
    }
}
