const fs = require("fs");
const path = require("path");
/**
 * Converts Solidity interface types to 'address' for ABI compatibility.
 * @param {string} solidityType - The Solidity type (e.g. "IERC20", "address", "uint256")
 * @returns {string} The ABI-compatible type.
 */
function convertToABIType(solidityType) {
    // Check if it's an interface type (starts with 'I' followed by uppercase letter)
    // Common patterns: IERC20, IERC721, IStrategy, ILendingPool, etc.
    if (/^I[A-Z]/.test(solidityType)) {
      return "address";
    }
    return solidityType;
  }
  
  /**
   * Parses Solidity event parameter string into an ABI input object.
   * @param {string} paramStr - The parameter string (e.g. "address indexed from")
   * @returns {object} ABI input object.
   */
  function parseEventParameter(paramStr) {
      paramStr = paramStr.trim().replace(/;/g, '');
      if (!paramStr) return null;
      const tokens = paramStr.split(/\s+/);
      let indexed = false;
      let type, name;
      const filteredTokens = tokens.filter(token => {
        if (token === "indexed") {
          indexed = true;
          return false;
        }
        return true;
      });
      if (filteredTokens.length >= 2) {
        [type, name] = filteredTokens;
      } else if (filteredTokens.length === 1) {
        type = filteredTokens[0];
        name = "";
      } else {
        return null;
      }
      return {
        indexed,
        internalType: type,
        name,
        type: convertToABIType(type)
      };
    }
  
  /**
   * Recursively builds an ABI array of events by processing all Solidity files
   * in the given folder and following any import statements.
   * 
   * @param {string} baseFolderPath - The folder containing your Solidity files.
   * @returns {Array} An ABI array containing event fragments.
   */
  function buildEventsABI(baseFolderPath) {
    const processedFiles = new Set();
    const eventABI = [];
  
    function processFile(filePath) {
      if (processedFiles.has(filePath)) return;
      processedFiles.add(filePath);
      let content;
      try {
        content = fs.readFileSync(filePath, "utf8");
      } catch (e) {
        console.error(`Failed to read file ${filePath}:`, e);
        return;
      }
  
      const eventRegex = /event\s+(\w+)\s*\(([^)]*)\)\s*;/g;
      let match;
      while ((match = eventRegex.exec(content)) !== null) {
        const eventName = match[1];
        const paramsStr = match[2];
        const params = paramsStr.split(',')
          .map(param => parseEventParameter(param))
          .filter(param => param !== null);
        const eventFragment = {
          anonymous: false,
          inputs: params,
          name: eventName,
          type: "event"
        };
        const exists = eventABI.some(e => e.name === eventName && e.inputs.length === params.length);
        if (!exists) {
          eventABI.push(eventFragment);
        }
      }
  
      const importRegex = /import\s+["']([^"']+)["'];/g;
      while ((match = importRegex.exec(content)) !== null) {
        const importPath = match[1];
        let importedFilePath;
        if (importPath.startsWith("@openzeppelin/")) {
          importedFilePath = path.join(__dirname, "..", "node_modules", importPath);
        } else {
          importedFilePath = path.join(baseFolderPath, importPath);
        }
        if (fs.existsSync(importedFilePath)) {
          processFile(importedFilePath);
        } else {
          console.error(`Imported file not found: ${importedFilePath}`);
        }
      }
    }
  
    const files = fs.readdirSync(baseFolderPath);
    for (const file of files) {
      if (file.endsWith(".sol")) {
        const filePath = path.join(baseFolderPath, file);
        processFile(filePath);
      }
    }
    return eventABI;
  }
  
  function generateAttackContractSource(config) {
    const interfacesDir = path.join(__dirname, "..", "contracts/interfaces");
    let importLines = [];
    try {
      const files = fs.readdirSync(interfacesDir);
      files.forEach(file => {
        if (file.endsWith(".sol") && !file.includes("_hide_")) {
          importLines.push(`import "./interfaces/${file}";`);
        }
      });
    } catch (err) {
      console.error("Error reading interfaces folder:", err);
    }
    
    // Mapping from contract names to their interface types
    const typeMapping = {
      usdc: "IERC20",
      nisc: "IERC20",
      weth: "IWeth",
      lottery: "ILottery",
      lotteryExtension: "ILotteryExtension",
      auctionVault: "IAuctionVault",
      auctionManager: "IAuctionManager",
      lendingPoolStrategy: "IStrategy",
      exchangeVault: "IExchangeVault",
      productPools: "IPool",
      priceOracle: "IPriceOracle",
      lendingFactory: "ILendingFactory",
      lendingManagers: "ILendingManager",
      lendingPoolsA: "ILendingPool",
      lendingPoolsB: "ILendingPool",
      flashLoaner: "IFlashLoaner",
      investmentFactory: "IInvestmentVaultFactory",
      usdcIdleMarket: "IIdleMarket",
      investmentVaults: "IInvestmentVault",
      communityInsurance: "ICommunityInsurance",
      rewardDistributor: "IRewardDistributor"
    };
    
    const lines = [];
    lines.push("// SPDX-License-Identifier: MIT");
    lines.push("pragma solidity ^0.8.0;");
    lines.push("");
    lines.push('import "hardhat/console.sol";');
    lines.push('import "@openzeppelin/contracts/utils/math/Math.sol";');
    lines.push("");
    importLines.forEach(imp => lines.push(imp));
    lines.push("");
    lines.push("contract AttackContract {");
    
    for (const [key, value] of Object.entries(config)) {
      if (key === "snapshotId" || key === "attackTime") continue;
      
      const interfaceType = typeMapping[key];
      
      if (key === "lotteryExtension") {
        // Special case: lotteryExtension is same address as lottery, used via delegatecall
        lines.push(`    ILotteryExtension public constant lotteryExtension = ILotteryExtension(${config.lottery});`);
      } else if (Array.isArray(value)) {
        if (key === "productPools") {
          lines.push("    // Product pools: [0] = USDC/WETH pool, [1] = USDC/NISC pool");
        } else if (key === "lendingManagers") {
          lines.push("    // Lending managers: [0] = Lending Trio 1 manager, [1] = Lending Trio 2 manager");
        } else if (key === "investmentVaults") {
          lines.push("    // Investment vaults: [0] = USDC Strategy 1 vault, [1] = USDC Strategy 2 vault");
        }
        
        // Handle arrays with proper interface casting
        if (interfaceType) {
          const castedValues = value.map(addr => `${interfaceType}(${addr})`).join(", ");
          lines.push(`    ${interfaceType}[] public ${key} = [${castedValues}];`);
        } else {
          // Fallback for arrays without known interface type
          lines.push(`    address[] public ${key} = [${value.join(", ")}];`);
        }
      } else if (interfaceType) {
        // Single value with known interface type
        lines.push(`    ${interfaceType} public constant ${key} = ${interfaceType}(${value});`);
      } else {
        // Fallback for unknown types
        lines.push(`    address public constant ${key} = ${value};`);
      }
    }  

    lines.push("    constructor() payable {}");
    lines.push("    function Attack() public {");
    lines.push("        console.log('Attack contract deployed at:', address(this));");
    lines.push("        // Add your exploit or test logic here.");
    lines.push("\n");
    lines.push("        // Transfer all assets to the attacker");
    lines.push("        usdc.transfer(msg.sender, usdc.balanceOf(address(this)));");
    lines.push("        nisc.transfer(msg.sender, nisc.balanceOf(address(this)));");
    lines.push("        weth.transfer(msg.sender, weth.balanceOf(address(this)));");
    lines.push("        payable(msg.sender).transfer(address(this).balance);");
    lines.push("    }");
    lines.push("    receive() external payable {}");
    lines.push("}");
    
    
    return lines.join("\n");
  }

  module.exports = {
    parseEventParameter,
    buildEventsABI,
    generateAttackContractSource
  };