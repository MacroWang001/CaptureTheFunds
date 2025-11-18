// public/main.js

let referenceTime = null; // This will be set from the backend (attackTime)
let lotteryAddress = ""; // Global variable to store the Lottery contract address

async function updateUserBalance() {
  try {
    const response = await fetch('/balance');
    const data = await response.json();
    if (data.success) {
      // Update Score (total worth in ETH)
      const scoreElement = document.getElementById('user-balance-score');
      if (scoreElement && data.score !== undefined) {
        scoreElement.textContent = `Score: ${formatWithCommas(data.score.toFixed(4))} ETH`;
      }
      
      // Update ETH balance
      const ethElement = document.getElementById('user-balance-eth');
      if (ethElement) {
        ethElement.textContent = `ETH: ${formatWithCommas(data.eth.toFixed(4))}`;
      }
      
      // Update WETH balance
      const wethElement = document.getElementById('user-balance-weth');
      if (wethElement) {
        wethElement.textContent = `WETH: ${formatWithCommas(data.weth.toFixed(4))}`;
      }
      
      // Update USDC balance
      const usdcElement = document.getElementById('user-balance-usdc');
      if (usdcElement) {
        usdcElement.textContent = `USDC: ${formatWithCommas(data.usdc.toFixed(2))}`;
      }
      
      // Update NISC balance
      const niscElement = document.getElementById('user-balance-nisc');
      if (niscElement) {
        niscElement.textContent = `NISC: ${formatWithCommas(data.nisc.toFixed(2))}`;
      }
    }
  } catch (error) {
    console.error('Error fetching balance:', error);
    const scoreElement = document.getElementById('user-balance-score');
    if (scoreElement) {
      scoreElement.textContent = `Score: Error`;
    }
  }
}

async function fetchReferenceTime() {
  try {
    const res = await fetch("/contracts");
    const data = await res.json();
    referenceTime = data.attackTime;
  } catch (err) {
    console.error("Error fetching reference time:", err);
    referenceTime = Math.floor(Date.now() / 1000);
  }
}

async function updateHistoryCount() {
  try {
    const response = await fetch('/history-count');
    const data = await response.json();
    
    const badge = document.getElementById('history-count-badge');
    if (badge) {
      badge.textContent = data.count;
      
      // Change badge color if recording is disabled
      if (!data.recordingActive) {
        badge.classList.add('disabled');
        badge.title = 'History recording disabled - faucet was used';
      } else {
        badge.classList.remove('disabled');
        badge.title = `${data.count} attack${data.count !== 1 ? 's' : ''} recorded`;
      }
    }
  } catch (error) {
    console.error('Error fetching history count:', error);
  }
}

// Function to refresh all UI elements without page reload
async function refreshAllUIElements() {
  try {
    // Update balance and history
    await updateUserBalance();
    await updateHistoryCount();
    await fetchReferenceTime();
    await updateContractAddresses();
    
    // Clear submission results
    const submissionResult = document.getElementById("submissionResult");
    if (submissionResult) {
      submissionResult.innerHTML = "";
    }
    const replayResult = document.getElementById("replayResult");
    if (replayResult) {
      replayResult.innerHTML = "";
      replayResult.style.display = 'none';
    }
    
    // Get current active tab/subtab
    const activeTab = document.querySelector(".tab-content.active");
    const activeSubTab = document.querySelector(".subtab-content.active");
    
    // Update protocol data based on active tab
    if (activeTab && activeTab.id === "protocols") {
      if (activeSubTab) {
        const subTabName = activeSubTab.id;
        
        // Update based on which subtab is active
        if (subTabName === "auction") {
          await updateAuctionsTable();
          await updatePopularAuctionTokens();
          await updateAuctionVaultInfo();
        } else if (subTabName === "lottery") {
          await updateLotteryLiquidity();
          await updateTicketsTable();
          await updateLotteryChallenges();
        } else if (subTabName === "exchange") {
          await updateExchangeFee();
          await updatePools();
        } else if (subTabName === "lending") {
          await updateOraclePrices();
          await updateFlashloanFee();
          await updateFlashloanMaxAmounts();
          await updateLending();
        } else if (subTabName === "investment") {
          await updateInvestment();
        } else if (subTabName === "community-insurance") {
          await updateCommunityInsurance();
        }
      }
    }
    
    console.log("UI refresh completed");
  } catch (error) {
    console.error("Error refreshing UI elements:", error);
  }
}

fetchReferenceTime();
updateUserBalance();
updateHistoryCount();

function formatRelativeTime(timestamp) {
  if (referenceTime === null) {
    referenceTime = Math.floor(Date.now() / 1000);
  }
  const diff = timestamp - referenceTime;
  const absDiff = Math.abs(diff);
  const hours = Math.floor(absDiff / 3600);
  if (diff > 0) {
    return `${hours} hours from now`;
  } else if (diff < 0) {
    return `${hours} hours ago`;
  } else {
    return "now";
  }
}

// helper: turn "1.23e+3" or "4.56E-2" into "1230" or "0.0456", etc.
function expandExponential(str) {
  const match = str.match(/^([+-]?)(\d+)(?:\.(\d*))?[eE]([+-]?\d+)$/);
  if (!match) return str;
  const [, sign, intPart, fracPart = "", expRaw] = match;
  const exp = parseInt(expRaw, 10);
  const digits = intPart + fracPart;
  const origDecimalIndex = intPart.length;
  const newIndex = origDecimalIndex + exp;

  if (exp >= 0) {
    // shift decimal right
    const neededZeros = Math.max(0, exp - fracPart.length);
    const full = digits + "0".repeat(neededZeros);
    if (full.length > newIndex) {
      return sign + full.slice(0, newIndex) + "." + full.slice(newIndex);
    } else {
      return sign + full; 
    }
  } else {
    // shift decimal left
    if (newIndex > 0) {
      return sign + digits.slice(0, newIndex) + "." + digits.slice(newIndex);
    } else {
      return sign + "0." + "0".repeat(-newIndex) + digits;
    }
  }
}

function formatWithCommas(value) {
  // convert Number→String (NB: large Numbers may already be in "e" form)
  let str = typeof value === "number" ? value.toString() : value;
  // expand any scientific notation
  if (/[eE]/.test(str)) {
    str = expandExponential(str);
  }
  // split integer / fractional
  let [intPart, fracPart] = str.split(".");
  // insert commas in integer part
  intPart = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  // cap fractional to 6 digits
  if (fracPart !== undefined) {
    fracPart = fracPart.slice(0, 6);
    return `${intPart}.${fracPart}`;
  }
  return intPart;
}

async function updateContractAddresses() {
  try {
    const res = await fetch("/contracts");
    const data = await res.json();
    lotteryAddress = data.lottery;
  } catch (err) {
    console.error("Error updating contract addresses:", err);
  }
}


async function updateLotteryLiquidity() {
  try {
    const res = await fetch("/lottery-liquidity");
    const data = await res.json();
    // Assuming USDC has 6 decimals. Format the liquidity value.
    const liquidity = ethers.utils.formatUnits(data.liquidity, 6);
    document.getElementById("lottery-liquidity").innerText = formatWithCommas(liquidity);
    
    // Format and display ticket price (also in USDC with 6 decimals)
    const ticketPrice = ethers.utils.formatUnits(data.ticketPrice, 6);
    document.getElementById("ticket-price").innerText = formatWithCommas(ticketPrice);
  } catch (err) {
    console.error("Error updating lottery liquidity:", err);
    document.getElementById("lottery-liquidity").innerText = "Error";
    document.getElementById("ticket-price").innerText = "Error";
  }
}

async function updateTicketsTable() {
  try {
    const res = await fetch("/tickets");
    const data = await res.json();
    
    // Update the available tickets count
    const availableTicketsElement = document.getElementById("available-tickets");
    availableTicketsElement.textContent = data.availableTickets || 0;
    
    // Update the tickets table
    const tableBody = document.getElementById("tickets-table-body");
    tableBody.innerHTML = "";
    data.tickets.forEach(ticket => {
      const row = document.createElement("tr");
      row.innerHTML = `
        <td>${ticket.id}</td>
        <td>${formatRelativeTime(ticket.purchaseTime)}</td>
        <td>${formatRelativeTime(ticket.expirationTime)}</td>
        <td>${ticket.redeemed ? "Yes" : "No"}</td>
        <td>${ticket.revealed ? "Yes" : "No"}</td>
        <td>${formatRelativeTime(ticket.revealDeadline)}</td>
      `;
      tableBody.appendChild(row);
    });
  } catch (err) {
    console.error("Error updating tickets table:", err);
  }
}

async function updateLotteryChallenges() {
  try {
    const res = await fetch("/lottery-challenges");
    const data = await res.json();
    
    // Store challenges in a global variable for filtering
    window.lotteryChallenges = data.challenges;
    
    // Display all challenges by default
    displayChallenges(window.lotteryChallenges);
    
    // Set up challenge filter buttons
    document.getElementById("show-all-challenges").addEventListener("click", function() {
      setActiveFilterButton(this);
      displayChallenges(window.lotteryChallenges);
    });
    
    document.getElementById("show-unsolved-challenges").addEventListener("click", function() {
      setActiveFilterButton(this);
      const unsolvedChallenges = window.lotteryChallenges.filter(challenge => !challenge.solved);
      displayChallenges(unsolvedChallenges);
    });
    
    document.getElementById("show-solved-challenges").addEventListener("click", function() {
      setActiveFilterButton(this);
      const solvedChallenges = window.lotteryChallenges.filter(challenge => challenge.solved);
      displayChallenges(solvedChallenges);
    });
    
  } catch (err) {
    console.error("Error updating lottery challenges:", err);
    document.getElementById("challenges-table-body").innerHTML = `
      <tr>
        <td colspan="4">Error loading challenges. Please try again later.</td>
      </tr>
    `;
  }
}

function setActiveFilterButton(button) {
  // Remove active class from all filter buttons
  document.querySelectorAll(".challenge-filter-btn").forEach(btn => {
    btn.classList.remove("active");
  });
  
  // Add active class to the clicked button
  button.classList.add("active");
}

function displayChallenges(challenges) {
  const tableBody = document.getElementById("challenges-table-body");
  tableBody.innerHTML = "";
  
  if (challenges.length === 0) {
    tableBody.innerHTML = `
      <tr>
        <td colspan="4">No challenges match the selected filter.</td>
      </tr>
    `;
    return;
  }
  
  // Sort challenges by ID (ascending)
  challenges.sort((a, b) => a.id - b.id);
  
  challenges.forEach(challenge => {
    const row = document.createElement("tr");
    const statusClass = challenge.solved ? "status-solved" : "status-unsolved";
    const statusText = challenge.solved ? "Solved" : "Unsolved";
    
    row.innerHTML = `
      <td>${challenge.id}</td>
      <td>${challenge.name}</td>
      <td>${challenge.prize}</td>
      <td><span class="status-badge ${statusClass}">${statusText}</span></td>
    `;
    
    tableBody.appendChild(row);
  });
}

async function updateAuctionsTable() {
  try {
    const resAuctions = await fetch("/auctions");
    const { auctions } = await resAuctions.json();
    console.log("Auctions fetched from server:", auctions);
    
    // Separate auctions by type: regular (non-dutch) vs. dutch
    const regularAuctions = auctions.filter(auction => !auction.isDutch);
    const dutchAuctions = auctions.filter(auction => auction.isDutch);

    const tableBodyRegular = document.getElementById("auction-table-body-regular");
    const tableBodyDutch = document.getElementById("auction-table-body-dutch");
    tableBodyRegular.innerHTML = "";
    tableBodyDutch.innerHTML = "";

    // Process Regular Auctions (assume using USDC, 6 decimals)
    regularAuctions.forEach(auction => {
      const auctionId = auction.auctionId.toString();
      let nftAsset;
      // Ensure we have the Lottery address available (if not, this comparison will fail; verify updateContractAddresses() is called first).
      if (lotteryAddress && auction.nftContract.toLowerCase() === lotteryAddress.toLowerCase()) {
        nftAsset = `NFT Lottery Ticket #${auction.tokenId}`;
      } else {
        nftAsset = `NFT ${auction.nftContract} #${auction.tokenId}`;
      }
      const askingPrice = formatWithCommas(ethers.utils.formatUnits(auction.askingPrice, 6)) + " USDC";
      const highestBid = formatWithCommas(ethers.utils.formatUnits(auction.highestBid, 6)) + " USDC";
      const startTimeRelative = formatRelativeTime(Number(auction.startTime));
      const endTimeRelative = formatRelativeTime(Number(auction.endTime));
      const settledStatus = auction.settled ? "Yes" : "No";
      const row = document.createElement("tr");
      row.innerHTML = `
        <td>${auctionId}</td>
        <td>${nftAsset}</td>
        <td>${askingPrice}</td>
        <td>${highestBid}</td>
        <td>${startTimeRelative}</td>
        <td>${endTimeRelative}</td>
        <td>${settledStatus}</td>
      `;
      tableBodyRegular.appendChild(row);
    });

    // Process Dutch Auctions: show current price and minimum price
    dutchAuctions.forEach(auction => {
      const auctionId = auction.auctionId.toString();
      let nftAsset;
      // Ensure we have the Lottery address available (if not, this comparison will fail; verify updateContractAddresses() is called first).
      if (lotteryAddress && auction.nftContract.toLowerCase() === lotteryAddress.toLowerCase()) {
        nftAsset = `NFT Lottery Ticket #${auction.tokenId}`;
      } else {
        nftAsset = `NFT ${auction.nftContract} #${auction.tokenId}`;
      }
      // Use the currentPrice returned by the server (assumed to be in wei, with 18 decimals)
      const currentPrice = formatWithCommas(ethers.utils.formatUnits(auction.currentPrice || "0", 18)) + " NISC";
      const minPrice = formatWithCommas(ethers.utils.formatUnits(auction.minPrice, 18)) + " NISC";
      const startTimeRelative = formatRelativeTime(Number(auction.startTime));
      const endTimeRelative = formatRelativeTime(Number(auction.endTime));
      const settledStatus = auction.settled ? "Yes" : "No";
      const row = document.createElement("tr");
      row.innerHTML = `
        <td>${auctionId}</td>
        <td>${nftAsset}</td>
        <td>${currentPrice}</td>
        <td>${minPrice}</td>
        <td>${startTimeRelative}</td>
        <td>${endTimeRelative}</td>
        <td>${settledStatus}</td>
      `;
      tableBodyDutch.appendChild(row);
    });
  } catch (err) {
    console.error("Error updating auctions table:", err);
  }
}

async function updateExchangeFee() {
  try {
    const res = await fetch("/exchange-fee");
    const data = await res.json();
    // Convert fee from basis points to a decimal rate.
    // (E.g., if fee is 2 basis points, then feeRate = 2 / 10000 = 0.0002)
    window.globalFee = parseFloat(data.fee) / 10000;
    document.getElementById("global-fee").innerText = (globalFee * 100).toFixed(2) + "%";
  } catch (err) {
    console.error("Error updating exchange fee:", err);
    window.globalFee = 0;
    document.getElementById("global-fee").innerText = "0%";
  }
}

// Updated function: display pool composition with a pie chart on the left and details on the right,
// plus an improved swap calculator to support multiple pools with arbitrary tokens.
async function updatePools() {
  try {
    const res = await fetch("/pools");
    const data = await res.json();
    const poolsContainer = document.getElementById("pools-container");
    poolsContainer.innerHTML = ""; // Clear existing content

    // Fetch live prices from PriceOracle
    const priceRes = await fetch("/price-oracle");
    const priceData = await priceRes.json();
    // Convert the returned values from 1e18 precision to numbers.
    const usdcPrice = parseFloat(ethers.utils.formatUnits(priceData.usdcPrice, 18));
    const wethPrice = parseFloat(ethers.utils.formatUnits(priceData.wethPrice, 18));
    const niscPrice = parseFloat(ethers.utils.formatUnits(priceData.niscPrice, 18));
    // Compute conversion rates relative to USDC (which is 1 USDC = 1 USDC)
    const conversionRates = {
      USDC: 1,
      WETH: wethPrice / usdcPrice, // e.g., approximately 2000
      NISC: niscPrice / usdcPrice  // e.g., if 1 USDC = 4 NISC then niscPrice should be about 0.25
    };

    // Define colors for tokens: USDC => green, WETH => pink, NISC => blue.
    const tokenColors = {
      USDC: "#008000",
      WETH: "#ff69b4",
      NISC: "#0000ff"
    };

    data.pools.forEach((pool, index) => {
      const poolDiv = document.createElement("div");
      poolDiv.classList.add("pool");
      poolDiv.style.marginBottom = "2rem";

      // Pool name header
      const header = document.createElement("h4");
      header.innerText = pool.poolName;
      poolDiv.appendChild(header);

      // Compute total liquidity in USD dynamically for all tokens in the pool
      let totalLiquidityUSD = 0;
      const tokenUSDValues = pool.tokens.map(token => {
        const reserve = parseFloat(token.reserve);
        const rate = conversionRates[token.symbol] || 1;
        const usdValue = reserve * rate;
        totalLiquidityUSD += usdValue;
        return usdValue;
      });
      totalLiquidityUSD = parseFloat(totalLiquidityUSD.toFixed(2));

      // Create a flex container for composition details
      const compositionContainer = document.createElement("div");
      compositionContainer.classList.add("composition-container");
      compositionContainer.style.display = "flex";
      compositionContainer.style.alignItems = "center";
      compositionContainer.style.justifyContent = "space-between";
      compositionContainer.style.margin = "1rem 0";

      // Left: Pie chart container
      const pieDiv = document.createElement("div");
      pieDiv.classList.add("pie-chart-container");
      pieDiv.style.flex = "1";
      pieDiv.style.marginRight = "1rem";
      const canvas = document.createElement("canvas");
      canvas.id = `poolChart-${index}`;
      canvas.style.maxWidth = "300px";
      canvas.style.margin = "0";
      pieDiv.appendChild(canvas);
      compositionContainer.appendChild(pieDiv);

      // Right: Pool composition table (like community insurance)
      const detailsDiv = document.createElement("div");
      detailsDiv.classList.add("pool-details");
      detailsDiv.style.flex = "1";
      // Create table
      const table = document.createElement("table");
      table.style.width = "100%";
      table.style.marginTop = "1rem";
      const thead = document.createElement("thead");
      thead.innerHTML = `
        <tr>
          <th>Asset</th>
          <th>Amount</th>
          <th>$ Value</th>
        </tr>
      `;
      table.appendChild(thead);
      const tbody = document.createElement("tbody");
      pool.tokens.forEach((token, i) => {
        const reserve = parseFloat(token.reserve);
        const usdValue = tokenUSDValues[i];
        const row = document.createElement("tr");
        row.innerHTML = `
          <td>${token.symbol}</td>
          <td>${formatWithCommas(reserve)}</td>
          <td>$${formatWithCommas(usdValue.toFixed(2))}</td>
        `;
        tbody.appendChild(row);
      });
      // Add total row
      const totalRow = document.createElement("tr");
      totalRow.style.fontWeight = "bold";
      totalRow.innerHTML = `
        <td>Total</td>
        <td></td>
        <td>$${formatWithCommas(totalLiquidityUSD.toFixed(2))}</td>
      `;
      tbody.appendChild(totalRow);
      table.appendChild(tbody);
      detailsDiv.appendChild(table);
      compositionContainer.appendChild(detailsDiv);
      poolDiv.appendChild(compositionContainer);

      // Improved Swap Calculator Section
      const calcDiv = document.createElement("div");
      calcDiv.classList.add("pool-calculator");
      calcDiv.style.marginTop = "1rem";
      // Build the options for the token select element dynamically based on pool.tokens
      const tokenOptions = pool.tokens.map(token => `<option value="${token.symbol}">${token.symbol}</option>`).join('');
      calcDiv.innerHTML = `
        <h5 style="font-size:1.2em; font-weight:bold;">Swap Calculator</h5>
        <label for="inputToken-${index}">Input Token:</label>
        <select id="inputToken-${index}">
          ${tokenOptions}
        </select>
        <br>
        <label for="inputAmount-${index}">Input Amount:</label>
        <input type="number" id="inputAmount-${index}" placeholder="Enter amount" />
        <button id="calcBtn-${index}" style="padding:0.2em 0.5em; font-size:0.8em;">Calculate Output</button>
        <p id="calcResult-${index}"></p>
      `;
      poolDiv.appendChild(calcDiv);
      poolDiv.querySelector(`#calcBtn-${index}`).addEventListener("click", () => {
        const inputToken = document.getElementById(`inputToken-${index}`).value;
        const inputAmount = parseFloat(document.getElementById(`inputAmount-${index}`).value);
        if (isNaN(inputAmount) || inputAmount <= 0) {
          document.getElementById(`calcResult-${index}`).innerText = "Enter a valid amount.";
          return;
        }
        // For simplicity, assume two-token pools and a constant product model:
        let inputReserve, outputReserve, outputToken;
        if (pool.tokens[0].symbol === inputToken) {
          inputReserve = parseFloat(pool.tokens[0].reserve);
          outputReserve = parseFloat(pool.tokens[1].reserve);
          outputToken = pool.tokens[1].symbol;
        } else {
          inputReserve = parseFloat(pool.tokens[1].reserve);
          outputReserve = parseFloat(pool.tokens[0].reserve);
          outputToken = pool.tokens[0].symbol;
        }
        const netInput = inputAmount / (1 + globalFee);
        const outputAmount = (outputReserve * netInput) / (inputReserve + netInput);
        document.getElementById(`calcResult-${index}`).innerText =
          `Swapping ${formatWithCommas(inputAmount)} ${inputToken} yields approximately ${formatWithCommas(outputAmount)} ${outputToken}`;
      });

      // Generate the pie chart:
      const tokenValues = tokenUSDValues;
      const totalUSDForChart = tokenValues.reduce((acc, val) => acc + val, 0);
      const percentages = tokenValues.map(val => ((val / totalUSDForChart) * 100).toFixed(2));
      const colors = pool.tokens.map(token => tokenColors[token.symbol] || "gray");

      const ctx = canvas.getContext("2d");
      new Chart(ctx, {
        type: 'pie',
        data: {
          labels: pool.tokens.map(token => token.symbol),
          datasets: [{
            data: tokenValues,
            backgroundColor: colors
          }]
        },
        options: {
          plugins: {
            legend: {
              onClick: () => {}
            },
            tooltip: {
              callbacks: {
                label: function(context) {
                  const idx = context.dataIndex;
                  const token = pool.tokens[idx];
                  const valueUSD = tokenValues[idx];
                  const percent = percentages[idx];
                  return `${token.symbol}: $${formatWithCommas(valueUSD.toFixed(2))} (${percent}%)`;
                }
              }
            }
          }
        }
      });

      poolsContainer.appendChild(poolDiv);
    });
  } catch (err) {
    console.error("Error updating pools:", err);
  }
}

async function updateOraclePrices() {
  try {
    const res  = await fetch("/price-oracle");
    const data = await res.json();

    const usdcPrice = ethers.utils.formatUnits(data.usdcPrice, 18);
    const niscPrice = ethers.utils.formatUnits(data.niscPrice, 18);
    const wethPrice = ethers.utils.formatUnits(data.wethPrice, 18);
    document.getElementById("oracle-usdc").innerText = "$" + usdcPrice;
    document.getElementById("oracle-nisc").innerText = "$" + niscPrice;
    document.getElementById("oracle-weth").innerText = "$" + wethPrice;
  } catch (err) {
    console.error("Error updating oracle prices:", err);
  }
}

async function updateFlashloanFee() {
  try {
    const res = await fetch("/flashloan-fee");
    const data = await res.json();
    const flashloanFee = parseFloat(data.fee) / 10000;
    document.getElementById("flashloan-fee").innerText = (flashloanFee * 100).toFixed(2) + "%";
  } catch (err) {
    console.error("Error updating flashloan fee:", err);
    document.getElementById("flashloan-fee").innerText = "Error";
  }
}

async function updateFlashloanMaxAmounts() {
  try {
    const res = await fetch("/flashloan-max-amounts");
    const data = await res.json();
    
    // Update each token's max flashloan amount
    data.tokens.forEach(token => {
      const amount = ethers.utils.formatUnits(token.amount, token.decimals);
      const elementId = `flashloan-max-${token.symbol.toLowerCase()}`;
      const element = document.getElementById(elementId);
      if (element) {
        element.innerText = formatWithCommas(amount);
      }
    });
  } catch (err) {
    console.error("Error updating flashloan max amounts:", err);
    document.getElementById("flashloan-max-usdc").innerText = "Error";
    document.getElementById("flashloan-max-nisc").innerText = "Error";
    document.getElementById("flashloan-max-weth").innerText = "Error";
  }
}

// ──────────────────────────────────────────────────────────────
// updateLending()
// Layout change: for every pool row the **text column** occupies the
// left‑hand third and the **bar chart** spans the middle + right two‑thirds,
// vertically centred within the row.
// ──────────────────────────────────────────────────────────────
async function updateLending() {
  try {
    // 1. fetch on‑chain state
    const { trios }     = await (await fetch("/lending")).json();
    const contractsData = await (await fetch("/contracts")).json();

    const lendingContainer = document.getElementById("lending-container");
    lendingContainer.innerHTML = "";

    // token‑address → symbol map
    const addr2sym = {};
    if (contractsData.usdc) addr2sym[contractsData.usdc.toLowerCase()] = "USDC";
    if (contractsData.nisc) addr2sym[contractsData.nisc.toLowerCase()] = "NISC";
    if (contractsData.weth) addr2sym[contractsData.weth.toLowerCase()] = "WETH";

    const decimals = { USDC: 6, WETH: 18, NISC: 18 };

    // ───────── per‑trio ────────────────────────────────────────
    trios.forEach((trio, idxTrio) => {
      const trioCard = document.createElement("div");
      trioCard.classList.add("lending-frame");
      trioCard.style.marginBottom = "2rem";

      const h4 = document.createElement("h4");
      h4.textContent = `Lending Trio ${idxTrio + 1}`;
      trioCard.appendChild(h4);

      const pools = [
        { label: "A", ...trio.tokenA },
        { label: "B", ...trio.tokenB }
      ];

      // ───────── per‑pool ──────────────────────────────────────
      pools.forEach(pool => {
        const sym  = addr2sym[(pool.asset ?? "").toLowerCase()] || "Unknown";
        const decs = decimals[sym] ?? 18;

        const total = Number(ethers.utils.formatUnits(pool.totalAssets, decs));
        const cash  = Number(ethers.utils.formatUnits(pool.cash,        decs));
        const debt  = total - cash;

        // Build a row with flex layout
        const row = document.createElement("div");
        row.style.display       = "flex";
        row.style.alignItems    = "center";
        row.style.gap           = "1rem";
        row.style.marginBottom  = "1.2rem";

        // ─── left third: text stats ───
        const txt = document.createElement("div");
        txt.style.flex = "1";          // ~⅓
        txt.innerHTML = `
          <h5 style="margin:0 0 0.4rem 0;">Pool ${pool.label} (${sym})</h5>
          <p style="margin:0"><strong>Total Assets:</strong> ${formatWithCommas(total)}</p>
          <p style="margin:0"><strong>Cash:</strong> ${formatWithCommas(cash)}</p>
          <p style="margin:0"><strong>Annual Rate:</strong> ${(Number(pool.annualRate)*100/1e18).toFixed(2)}%</p>
          <p style="margin:0"><strong>Fee:</strong> ${(Number(pool.feePercentage)*100/1e18).toFixed(2)}%</p>
          <p style="margin:0"><strong>Shares:</strong> ${formatWithCommas(pool.shares ?? "0")}</p>
        `;
        row.appendChild(txt);

        // ─── right two‑thirds: horizontal bar ───
        const chartWrap = document.createElement("div");
        chartWrap.style.flex              = "2";    // ~⅔
        chartWrap.style.display           = "flex";
        chartWrap.style.justifyContent    = "center";
        chartWrap.style.alignItems        = "center";

        if (total > 0) {
          // colours per token
          const pal = sym === "USDC" ? ["#008000","#70db70"]
                   : sym === "NISC" ? ["#0000ff","#99ccff"]
                   : sym === "WETH" ? ["#ff69b4","#ffb6c1"]
                   : ["gray","lightgray"];

          const canvas = document.createElement("canvas");
          canvas.width  = 360;
          canvas.height = 80;
          chartWrap.appendChild(canvas);

          new Chart(canvas.getContext("2d"), {
            type: "bar",
            data: {
              labels: [""],
              datasets: [
                { label: "Cash", data: [cash],  backgroundColor: pal[0] },
                { label: "Debt", data: [debt],  backgroundColor: pal[1] }
              ]
            },
            options: {
              responsive: false,
              maintainAspectRatio: false,
              indexAxis: "y",
              scales: {
                x: {
                  stacked: true,
                  beginAtZero: true,
                  max: total,
                  ticks: { display: false },
                  grid:  { display:false }
                },
                y: { stacked: true, ticks:{display:false}, grid:{display:false} }
              },
              layout: { padding:{top:10,bottom:10,left:0,right:0} },
              plugins: {
                legend: { display:false },
                tooltip: {
                  callbacks: {
                    label: ctx => `${ctx.dataset.label}: ${formatWithCommas(ctx.parsed.x)}`
                  }
                }
              }
            }
          });
        } else {
          chartWrap.textContent = "No assets yet.";
          chartWrap.style.color = "#bbb";
        }

        row.appendChild(chartWrap);
        trioCard.appendChild(row);
      });

      lendingContainer.appendChild(trioCard);
    });

    // refresh liquidation section underneath every trio
    await updateLiquidatablePositions();
  } catch (err) {
    console.error("Error in updateLending():", err);
  }
}

async function updateLiquidatablePositions() {
  try {
    const [lendRes, liqRes, contractsRes] = await Promise.all([
      fetch("/lending"),
      fetch("/lending-liquidatable"),
      fetch("/contracts")
    ]);
    const { trios } = await lendRes.json();
    const { managers } = await liqRes.json();
    const contractsData = await contractsRes.json();

    // build a lookup from asset address → symbol
    const knownTokens = {};
    if (contractsData.usdc) knownTokens[contractsData.usdc.toLowerCase()] = "USDC";
    if (contractsData.nisc) knownTokens[contractsData.nisc.toLowerCase()] = "NISC";
    if (contractsData.weth) knownTokens[contractsData.weth.toLowerCase()] = "WETH";

    const container = document.getElementById("lending-container");

    managers.forEach(entry => {
      // find the matching trio index
      const idx = trios.findIndex(
        t => t.manager.toLowerCase() === entry.manager.toLowerCase()
      );
      if (idx === -1) return;
      const trioDiv = container.children[idx];

      // clear any old sections
      Array.from(trioDiv.querySelectorAll(".liquidatable-section"))
           .forEach(el => el.remove());

      // determine tokenA/tokenB symbols for this trio
      const tokenAAddr = trios[idx].tokenA.asset.toLowerCase();
      const tokenBAddr = trios[idx].tokenB.asset.toLowerCase();
      const symA = knownTokens[tokenAAddr] || "UNKNOWN";
      const symB = knownTokens[tokenBAddr] || "UNKNOWN";

      // merge both lists into one array of positions
      const allPositions = [];

      // getLiquidatableA: debt in A, collateral in B
      entry.liquidatableA.forEach(p => {
        allPositions.push({
          user: p.user,
          collateralAmount: p.collateralAmount,
          debtAmount:      p.debtAmount,
          collateralToken: symB,
          debtToken:       symA
        });
      });

      // getLiquidatableB: debt in B, collateral in A
      entry.liquidatableB.forEach(p => {
        allPositions.push({
          user: p.user,
          collateralAmount: p.collateralAmount,
          debtAmount:      p.debtAmount,
          collateralToken: symA,
          debtToken:       symB
        });
      });

      if (allPositions.length === 0) return;

      // build the section
      const section = document.createElement("div");
      section.classList.add("liquidatable-section");
      section.style.marginTop = "1rem";

      const header = document.createElement("h5");
      header.innerText = "Liquidatable Positions";
      section.appendChild(header);

      const table = document.createElement("table");
      table.style.width = "100%";
      table.style.marginTop = "0.5rem";
      table.innerHTML = `
        <thead>
          <tr>
            <th>User</th>
            <th>Collateral Amount</th>
            <th>Debt Amount</th>
          </tr>
        </thead>
      `;

      const tbody = document.createElement("tbody");
      allPositions.forEach(pos => {
        const tr = document.createElement("tr");

        // format debt by dividing by token decimals
        const debtDecimals = pos.debtToken === "USDC" ? 6 : 18;
        const formattedDebt = ethers.utils.formatUnits(pos.debtAmount, debtDecimals);

        // format collateral amount by dividing by token decimals
        const collateralDecimals = pos.collateralToken === "USDC" ? 6 : 18;
        const formattedCollateral = ethers.utils.formatUnits(pos.collateralAmount, collateralDecimals);

        tr.innerHTML = `
          <td>${pos.user}</td>
          <td>${formatWithCommas(formattedCollateral)} ${pos.collateralToken}</td>
          <td>${formatWithCommas(formattedDebt)} ${pos.debtToken}</td>
        `;
        tbody.appendChild(tr);
      });

      table.appendChild(tbody);
      section.appendChild(table);
      trioDiv.appendChild(section);

    });
  } catch (err) {
    console.error("Error updating liquidatable positions:", err);
  }
}
// ──────────────────────────────────────────────────────────────
// updateInvestment()  ✦  v‑∞  (striped "infinite‑capacity" bars)
// ──────────────────────────────────────────────────────────────
async function updateInvestment() {
  try {
    const res        = await fetch("/investment");
    const { vaults } = await res.json();
    const container  = document.getElementById("investment-container");
    container.innerHTML = "";

    const MAX_UINT =
      "115792089237316195423570985008687907853269984665640564039457584007913129639935";

    const colours = { USDC: "#008000", NISC: "#0000ff", WETH: "#ff69b4" };
    const isInf = v => (typeof v === "string" && (v === MAX_UINT || v.length > 70));

    // helper to build a diagonal‑stripe pattern in given colour
    const makeStripePattern = (ctx, baseColour) => {
      const p = document.createElement("canvas");
      p.width = p.height = 8;
      const pc = p.getContext("2d");
      pc.fillStyle = baseColour;
      pc.fillRect(0, 0, 8, 8);
      pc.strokeStyle = "rgba(255,255,255,0.6)";
      pc.lineWidth = 4;
      pc.beginPath();
      pc.moveTo(0, 8);
      pc.lineTo(8, 0);
      pc.stroke();
      return ctx.createPattern(p, "repeat");
    };

    vaults.forEach(v => {
      // ───── card wrapper ─────
      const card = document.createElement("div");
      card.classList.add("investment-frame");
      card.style.marginBottom = "2rem";

      const title = document.createElement("h4");
      title.textContent = v.strategy;
      card.appendChild(title);

      // ───── find reference width (largest finite cap) ─────
      const finiteCaps = v.markets.filter(m => !isInf(m.cap)).map(m => Number(m.cap));
      const widthRef = finiteCaps.length ? Math.max(...finiteCaps) : 1;

      const labels        = [];
      const usedChartVals = [];
      const remChartVals  = [];
      const usedTrue      = [];
      const capsTrue      = [];
      const infFlags      = [];

      v.markets.forEach(m => {
        const inf = isInf(m.cap) || isInf(m.balance);
        infFlags.push(inf);

        const usedNum = Number(m.balance ?? 0);
        const capNum  = inf ? Infinity : Number(m.cap);

        labels.push(`${m.name || `Market ${m.id ?? ""}`}${inf ? " (∞)" : ""}`);
        usedChartVals.push(inf ? widthRef : usedNum);
        remChartVals.push(inf ? 0 : Math.max(capNum - usedNum, 0));

        usedTrue.push(usedNum);
        capsTrue.push(capNum);
      });

      // canvas sizing
      const perRow = 48;
      const canvas = document.createElement("canvas");
      canvas.width  = 460;
      canvas.height = Math.max(labels.length * perRow + 30, 150);
      card.appendChild(canvas);

      const ctx = canvas.getContext("2d");
      const tokenColour = colours[v.strategy.split(" ")[0]] || "#666";

      // build background array for "Used" dataset (striped if infinite)
      const usedBg = usedChartVals.map((_, i) =>
        infFlags[i] ? makeStripePattern(ctx, tokenColour) : tokenColour
      );

      new Chart(ctx, {
        type: "bar",
        data: {
          labels,
          datasets: [
            { label: "Used", data: usedChartVals, backgroundColor: usedBg, barThickness: 30 },
            { label: "Remaining", data: remChartVals, backgroundColor: "#444", barThickness: 30 }
          ]
        },
        options: {
          responsive: false,
          maintainAspectRatio: false,
          indexAxis: "y",
          layout: { padding: { left: 90, right: 10, top: 10, bottom: 10 } },
          scales: {
            x: {
              stacked: true,
              beginAtZero: true,
              max: widthRef,
              ticks: { display: false },
              grid: { display: false }
            },
            y: { stacked: true, grid: { display: false } }
          },
          plugins: {
            legend: { display: false },
            tooltip: {
              mode: "nearest",
              intersect: true,
              callbacks: {
                title: (items) => {
                  const i = items[0].dataIndex;
                  return labels[i];
                },
                label: (item) => {
                  const i = item.dataIndex;
                  const inf = infFlags[i];
                  const used = usedTrue[i];
                  const cap = capsTrue[i];
                  
                  if (item.dataset.label === "Used") {
                    return inf
                      ? `Used: ${formatWithCommas(used)}  (Cap: ∞)`
                      : `Used: ${formatWithCommas(used)}  (${((used / cap) * 100).toFixed(2)}% of cap)`;
                  }
                  return inf
                    ? "Remaining: ∞"
                    : `Remaining: ${formatWithCommas(remChartVals[i])}`;
                }
              }
            }
          }
        }
      });

      // Totals under chart
      const totals = document.createElement("p");
      totals.style.marginTop = "0.5rem";
      totals.innerHTML = `
        <strong>Total Assets:</strong> ${formatWithCommas(Number(v.totalAssets))}&nbsp;|&nbsp;
        <strong>Shares:</strong> ${formatWithCommas(Number(v.totalShares))}
      `;
      card.appendChild(totals);

      container.appendChild(card);
    });
  } catch (err) {
    console.error("Error updating investment UI:", err);
  }
}

async function updateCommunityInsurance() {
  try {
    const res = await fetch("/community-insurance");
    const data = await res.json();
    
    // Update insurance assets
    const assetsContainer = document.getElementById("insurance-assets-container");
    assetsContainer.innerHTML = "";
    
    if (data.communityInsurance.supportedAssets.length > 0) {
      // Create canvas for the chart
      const chartContainer = document.createElement("div");
      chartContainer.style.width = "100%";
      chartContainer.style.maxWidth = "500px";
      chartContainer.style.margin = "0 auto";
      
      const canvas = document.createElement("canvas");
      canvas.id = "insurance-assets-chart";
      chartContainer.appendChild(canvas);
      assetsContainer.appendChild(chartContainer);
      
      // Create table for the assets
      const table = document.createElement("table");
      table.style.width = "100%";
      table.style.marginTop = "1rem";
      
      const thead = document.createElement("thead");
      thead.innerHTML = `
        <tr>
          <th>Asset</th>
          <th>Amount</th>
          <th>$ Value</th>
        </tr>
      `;
      table.appendChild(thead);
      
      const tbody = document.createElement("tbody");
      
      // Fetch oracle prices for USD value calculation
      const priceRes = await fetch("/price-oracle");
      const priceData = await priceRes.json();
      
      const usdcPrice = parseFloat(ethers.utils.formatUnits(priceData.usdcPrice, 18));
      const niscPrice = parseFloat(ethers.utils.formatUnits(priceData.niscPrice, 18));
      const wethPrice = parseFloat(ethers.utils.formatUnits(priceData.wethPrice, 18));
      
      const priceMap = {
        "USDC": usdcPrice,
        "NISC": niscPrice,
        "WETH": wethPrice
      };
      
      // Colors for chart
      const colorMap = {
        "USDC": "#008000", // Green
        "NISC": "#0000ff", // Blue
        "WETH": "#ff69b4"  // Pink
      };
      
      // Prepare data for chart
      const labels = [];
      const values = [];
      const backgroundColors = [];
      let totalValueUSD = 0;
      
      data.communityInsurance.supportedAssets.forEach(asset => {
        const amount = parseFloat(ethers.utils.formatUnits(asset.balance, asset.decimals));
        const usdValue = amount * (priceMap[asset.symbol] || 1);
        totalValueUSD += usdValue;
        
        labels.push(asset.symbol);
        values.push(usdValue);
        backgroundColors.push(colorMap[asset.symbol] || "#888888");
        
        const row = document.createElement("tr");
        row.innerHTML = `
          <td>${asset.symbol}</td>
          <td>${formatWithCommas(amount)}</td>
          <td>$${formatWithCommas(usdValue.toFixed(2))}</td>
        `;
        tbody.appendChild(row);
      });
      
      // Add total row
      const totalRow = document.createElement("tr");
      totalRow.style.fontWeight = "bold";
      totalRow.innerHTML = `
        <td>Total</td>
        <td></td>
        <td>$${formatWithCommas(totalValueUSD.toFixed(2))}</td>
      `;
      tbody.appendChild(totalRow);
      
      table.appendChild(tbody);
      assetsContainer.appendChild(table);
      
      // Create pie chart
      new Chart(canvas, {
        type: 'pie',
        data: {
          labels: labels,
          datasets: [{
            data: values,
            backgroundColor: backgroundColors
          }]
        },
        options: {
          responsive: true,
          plugins: {
            legend: {
              position: 'right',
              onClick: () => {}
            },
            tooltip: {
              callbacks: {
                label: function(context) {
                  const value = context.parsed;
                  const total = context.dataset.data.reduce((a, b) => a + b, 0);
                  const percentage = ((value / total) * 100).toFixed(2);
                  return `${context.label}: $${formatWithCommas(value.toFixed(2))} (${percentage}%)`;
                }
              }
            }
          }
        }
      });
    } else {
      assetsContainer.innerHTML = "<p>No assets found.</p>";
    }
    
    // Update insurance parameters
    document.getElementById("minimal-withdraw").textContent = formatWithCommas(
      ethers.utils.formatUnits(data.communityInsurance.minimalWithdraw, 6)
    ) + " USDC";
    
    const withdrawDelayHours = parseInt(data.communityInsurance.withdrawDelay) / 3600;
    document.getElementById("withdraw-delay").textContent = 
      `${withdrawDelayHours} hours (${withdrawDelayHours/24} days)`;
    
    document.getElementById("total-supply").textContent = formatWithCommas(
      ethers.utils.formatUnits(data.communityInsurance.totalSupply, 0)
    ) + " shares";
    
    document.getElementById("free-supply").textContent = formatWithCommas(
      ethers.utils.formatUnits(data.communityInsurance.freeSupply, 0)
    ) + " shares";
    
    // Update reward distributor info
    document.getElementById("reward-token").textContent = data.rewardDistributor.rewardToken.symbol;
    
    document.getElementById("available-rewards").textContent = formatWithCommas(
      ethers.utils.formatUnits(
        data.rewardDistributor.rewardToken.balance,
        data.rewardDistributor.rewardToken.decimals
      )
    ) + " " + data.rewardDistributor.rewardToken.symbol;
    
    document.getElementById("reward-rate").textContent = formatWithCommas(
      ethers.utils.formatUnits(data.rewardDistributor.rewardRate, data.rewardDistributor.rewardToken.decimals)
    ) + " " + data.rewardDistributor.rewardToken.symbol;
    
    document.getElementById("optimal-supply").textContent = formatWithCommas(
      ethers.utils.formatUnits(data.rewardDistributor.optimalSupply, 0)
    ) + " shares";
    
  } catch (err) {
    console.error("Error updating community insurance UI:", err);
    document.getElementById("insurance-assets-container").innerHTML = 
      "<p>Error loading insurance data. Please try again later.</p>";
  }
}

async function updatePopularAuctionTokens() {
  try {
    const res = await fetch("/popular-auction-tokens");
    const data = await res.json();
    const tableBody = document.getElementById("auction-token-table-body");
    tableBody.innerHTML = "";
    data.popularTokens.forEach(tokenData => {
      const row = document.createElement("tr");
      row.innerHTML = `
        <td>${tokenData.symbol}</td>
        <td>${tokenData.auctionToken}</td>
        <td>${formatWithCommas(tokenData.totalShares)}</td>
        <td>${formatWithCommas(tokenData.underlyingBalance)}</td>
      `;
      tableBody.appendChild(row);
    });
  } catch (err) {
    console.error("Error updating popular auction tokens:", err);
  }
}

async function updateAuctionVaultInfo() {
  try {
    const auctionSubTab = document.getElementById('auction');
    if (!auctionSubTab) return;

    let container = document.getElementById("auction-vault-info-container");
    if (!container) {
      container = document.createElement('div');
      container.id = 'auction-vault-info-container';
      // Applying a style similar to other protocol sections.
      container.classList.add('lending-frame');
      container.style.padding = '1rem';
      container.style.marginTop = '2rem';

      const popularTokensTable = document.getElementById('auction-token-table-body')?.closest('table');

      if (popularTokensTable) {
        // Insert the new container after the popular tokens table.
        popularTokensTable.after(container);
      } else {
        // Fallback if the table isn't found
        auctionSubTab.appendChild(container);
      }
    }

    const res = await fetch("/auction-vault-info");
    const data = await res.json();

    const formattedAmount = ethers.utils.formatUnits(data.investedAmount, data.investedTokenDecimals);

    let strategyContent;
    if (data.strategyAddress === "0x0000000000000000000000000000000000000000") {
      strategyContent = `<p><strong>Current Strategy:</strong> None</p>`;
    } else {
      strategyContent = `
        <p><strong>Current Strategy:</strong> LendingPoolStrategy (${data.strategyAddress})</p>
        <p><strong>Amount Invested:</strong> ${formatWithCommas(formattedAmount)} ${data.investedTokenSymbol}</p>
      `;
    }

    container.innerHTML = `
      <h4>Auction Vault Strategy</h4>
      ${strategyContent}
    `;
  } catch (err) {
    console.error("Error updating auction vault info:", err);
    let container = document.getElementById("auction-vault-info-container");
    if (container) {
        container.innerHTML = "<h4>Auction Vault Strategy</h4><p>Error loading vault strategy info.</p>";
    }
  }
}

function switchTab(tabName) {
  const mainContent = document.querySelector('.main-content');
  if (tabName === 'submit') {
    mainContent.classList.add('submit-active');
  } else {
    mainContent.classList.remove('submit-active');
  }

  document.querySelectorAll(".tab-content").forEach(content => {
    content.classList.remove("active");
  });
  document.getElementById(tabName).classList.add("active");
  if (tabName === "submit") {
    editor.refresh();
  }
  if (tabName === "protocols") {
    updateAuctionsTable();
    updatePopularAuctionTokens();
    updateAuctionVaultInfo();
    updateLotteryLiquidity();
    updateTicketsTable();
    updateLotteryChallenges();
    updateExchangeFee();
    updateFlashloanFee();
    updateFlashloanMaxAmounts();
    updateContractAddresses();
  } else if (tabName === "exchange") {
    updatePools();
  }
}

document.querySelectorAll(".tab").forEach(tab => {
  tab.addEventListener("click", () => {
    document.querySelectorAll(".tab").forEach(t => t.classList.remove("active"));
    tab.classList.add("active");
    switchTab(tab.getAttribute("data-tab"));
  });
});

document.querySelectorAll(".sub-tab").forEach(subTab => {
  subTab.addEventListener("click", () => {
    document.querySelectorAll(".sub-tab").forEach(st => st.classList.remove("active"));
    subTab.classList.add("active");
    const subTabName = subTab.getAttribute("data-subtab");
    document.querySelectorAll(".subtab-content").forEach(content => {
      content.classList.remove("active");
    });
    document.getElementById(subTabName).classList.add("active");
    if (subTabName === "auction") {
      updateAuctionsTable();
      updateAuctionVaultInfo();
      updatePopularAuctionTokens();
    } else if (subTabName === "lottery") {
      updateTicketsTable();
      updateLotteryChallenges();
      updateLotteryLiquidity();
      updateContractAddresses();
    } else if (subTabName === "exchange") {
      updatePools();
    } else if (subTabName === "lending") {
      updateOraclePrices();
      updateFlashloanFee();
      updateFlashloanMaxAmounts();
      updateLending();
      updateLiquidatablePositions();
    } else if (subTabName === "investment") {
      updateInvestment();       
    } else if (subTabName === "community-insurance") {
      updateCommunityInsurance();
      // Remove all loadContractSource calls
    }
  });
});

function parseEvents(serverParsedEvents) {
  return serverParsedEvents.map(ev => {
    let argsDict = {};
    if (ev.arguments && typeof ev.arguments === "object" && !Array.isArray(ev.arguments)) {
      Object.entries(ev.arguments).forEach(([key, value]) => {
        if (isNaN(key)) {
          argsDict[key] = value;
        }
      });
    } else {
      argsDict = ev.arguments;
    }
    return {
      event: ev.event,
      arguments: argsDict,
      isUserGenerated: ev.isUserGenerated
    };
  });
}

function createEventCard(parsedEvent) {
  const card = document.createElement("div");
  card.classList.add("event-card");

  const header = document.createElement("h4");
  header.textContent = parsedEvent.event;
  card.appendChild(header);

  const argsObj = parsedEvent.arguments;
  if (Object.keys(argsObj).length > 0) {
    const list = document.createElement("ul");
    Object.keys(argsObj).forEach(argName => {
      const listItem = document.createElement("li");
      listItem.textContent = `${argName}: ${typeof argsObj[argName] === "object" ? JSON.stringify(argsObj[argName]) : argsObj[argName]}`;
      list.appendChild(listItem);
    });
    card.appendChild(list);
  } else {
    const noArgs = document.createElement("p");
    noArgs.textContent = "No arguments";
    card.appendChild(noArgs);
  }
  return card;
}

function displayParsedEvents(parsedEvents, containerId) {
  const container = document.getElementById(containerId);
  container.innerHTML = "";
  if (parsedEvents.length === 0) {
    container.innerText = "No events match the selected filter.";
    return;
  }
  parsedEvents.forEach(eventObj => {
    const card = createEventCard(eventObj);
    container.appendChild(card);
  });
}

function displayEventFiltersAndResults(resultElem, parsedEvents) {
    const eventNames = [...new Set(parsedEvents.map(e => e.event))].sort();

    const filterContainer = document.createElement('div');
    filterContainer.id = 'event-filter-container';
    
    const allButton = document.createElement('button');
    allButton.textContent = 'All Events';
    allButton.classList.add('event-filter-btn', 'active');
    filterContainer.appendChild(allButton);

    const userGeneratedButton = document.createElement('button');
    userGeneratedButton.textContent = 'User Generated';
    userGeneratedButton.classList.add('event-filter-btn');
    userGeneratedButton.dataset.eventName = 'user-generated'; // Special filter key
    filterContainer.appendChild(userGeneratedButton);

    eventNames.forEach(name => {
        if (name === "Unknown") return; // Don't create a filter for unknown events
        const btn = document.createElement('button');
        btn.textContent = name;
        btn.classList.add('event-filter-btn');
        btn.dataset.eventName = name;
        filterContainer.appendChild(btn);
    });

    const eventsContainer = document.createElement("div");
    eventsContainer.id = "parsed-events-container";

    resultElem.appendChild(filterContainer);
    resultElem.appendChild(eventsContainer);

    filterContainer.addEventListener('click', (e) => {
        if (e.target.tagName !== 'BUTTON') return;

        filterContainer.querySelectorAll('.event-filter-btn').forEach(b => b.classList.remove('active'));
        e.target.classList.add('active');

        const filterName = e.target.dataset.eventName;
        let filteredEvents;
        if (filterName === 'user-generated') {
            filteredEvents = parsedEvents.filter(ev => ev.isUserGenerated);
        } else if (filterName) {
            filteredEvents = parsedEvents.filter(ev => ev.event === filterName);
        } else {
            filteredEvents = parsedEvents;
        }
        
        displayParsedEvents(filteredEvents, 'parsed-events-container');
    });

    displayParsedEvents(parsedEvents, 'parsed-events-container');
}


// Modify the submit attack event listener
document.getElementById("submitAttack").addEventListener("click", async () => {
  const attackCode = editor.getValue();
  
  const resultElem = document.getElementById("submissionResult");
  resultElem.innerText = "Submitting attack...";
  try {
    const res = await fetch("/submit-attack", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: 'include', // Important for cookies
      body: JSON.stringify({ code: attackCode, replayMode: false })
    });
    
    
    const data = await res.json();
    if (data.error) {
      resultElem.innerText = data.error;
      
      // Display console logs even on error
      if (data.consoleLogs && data.consoleLogs.length > 0) {
        const consoleSection = document.createElement("div");
        consoleSection.style.marginTop = "1rem";
        consoleSection.style.padding = "1rem";
        consoleSection.style.backgroundColor = "#1e1e1e";
        consoleSection.style.borderRadius = "5px";
        consoleSection.style.border = "1px solid #444";
        
        const consoleHeader = document.createElement("h4");
        consoleHeader.textContent = "Console Output";
        consoleHeader.style.marginTop = "0";
        consoleHeader.style.color = "#00ff00";
        consoleSection.appendChild(consoleHeader);
        
        const consolePre = document.createElement("pre");
        consolePre.style.margin = "0";
        consolePre.style.whiteSpace = "pre-wrap";
        consolePre.style.color = "#00ff00";
        consolePre.style.fontFamily = "monospace";
        consolePre.textContent = data.consoleLogs.join("\n");
        consoleSection.appendChild(consolePre);
        
        resultElem.appendChild(consoleSection);
      }
    } else {
      resultElem.innerHTML = `<p>Attack executed! Your score: ${data.score} ETH</p>`;
      
      // Display console logs if available
      if (data.consoleLogs && data.consoleLogs.length > 0) {
        const consoleSection = document.createElement("div");
        consoleSection.style.marginTop = "1rem";
        consoleSection.style.padding = "1rem";
        consoleSection.style.backgroundColor = "#1e1e1e";
        consoleSection.style.borderRadius = "5px";
        consoleSection.style.border = "1px solid #444";
        
        const consoleHeader = document.createElement("h4");
        consoleHeader.textContent = "Console Output";
        consoleHeader.style.marginTop = "0";
        consoleHeader.style.color = "#00ff00";
        consoleSection.appendChild(consoleHeader);
        
        const consolePre = document.createElement("pre");
        consolePre.style.margin = "0";
        consolePre.style.whiteSpace = "pre-wrap";
        consolePre.style.color = "#00ff00";
        consolePre.style.fontFamily = "monospace";
        consolePre.textContent = data.consoleLogs.join("\n");
        consoleSection.appendChild(consolePre);
        
        resultElem.appendChild(consoleSection);
      }
      
      if (data.events && data.events.length > 0) {
        const parsed = parseEvents(data.events);
        displayEventFiltersAndResults(resultElem, parsed);
      } else {
        resultElem.innerHTML += "<p>No events emitted.</p>";
      }
      // Update the balance display after successful attack
      await updateUserBalance();
      // Update the history count badge
      await updateHistoryCount();
    }
  } catch (err) {
    resultElem.innerText = "Error submitting attack.";
    console.error("Error submitting attack:", err);
  }
});

// Replay functionality
document.getElementById("submitReplay").addEventListener("click", async () => {
  const fileInput = document.getElementById('replayFileInput');
  
  if (!fileInput.files[0]) {
    alert('Please select a replay file');
    return;
  }
  
  const resultElem = document.getElementById("replayResult");
  resultElem.style.display = 'block';
  resultElem.innerText = "Loading replay file...";
  
  try {
    const file = fileInput.files[0];
    const text = await file.text();
    
    resultElem.innerText = "Executing replay...";
    
    const res = await fetch("/submit-attack", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: 'include',
      body: JSON.stringify({ 
        replayMode: true, 
        replayFile: text, 
      })
    });
    
    const data = await res.json();
    if (data.error) {
      resultElem.innerText = data.error;
    } else {
      resultElem.innerHTML = `<p>${data.message || 'Replay executed!'} Your score: ${data.score} ETH</p>`;
      // Update the balance display after successful replay
      await updateUserBalance();
      // Update the replay count badge
      await updateHistoryCount();
    }
  } catch (err) {
    resultElem.innerText = "Error executing replay: " + err.message;
    console.error("Error executing replay:", err);
  }
});

// Download the history file
document.getElementById("downloadHistory").addEventListener("click", async () => {
  try {
    const response = await fetch('/download-history', {
      credentials: 'include'
    });
    
    if (response.ok) {
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `history-${Date.now()}.json`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } else {
      const data = await response.json();
      alert(data.error || 'Failed to download history');
    }
  } catch (err) {
    console.error('Error downloading history:', err);
    alert('Error downloading history');
  }
});


// Track current mode (normal = history recording, exploration = faucet available)
// Will be synced with backend on page load
let currentMode = 'normal';

// Function to sync mode with backend
async function syncModeWithBackend() {
  try {
    const response = await fetch('/mode');
    const data = await response.json();
    currentMode = data.mode || 'normal';
    // Update localStorage to match backend
    localStorage.setItem('ctfMode', currentMode);
    console.log('Mode synced with backend:', currentMode);
  } catch (error) {
    console.error('Error syncing mode with backend:', error);
    // Fallback to localStorage or default
    currentMode = localStorage.getItem('ctfMode') || 'normal';
  }
}

// Add session check to DOMContentLoaded
document.addEventListener('DOMContentLoaded', async () => {
  // First, sync mode with backend
  await syncModeWithBackend();
  const style = document.createElement('style');
  style.textContent = `
    .event-filter-btn {
        background-color: #333;
        color: white;
        border: 1px solid #555;
        padding: 5px 10px;
        margin: 2px;
        border-radius: 5px;
        cursor: pointer;
        transition: background-color 0.2s;
    }
    .event-filter-btn.active {
        background-color: #007bff;
        border-color: #007bff;
    }
    .event-filter-btn:hover:not(.active) {
        background-color: #555;
    }
    #event-filter-container {
        margin-bottom: 1rem;
        flex-wrap: wrap;
    }
  `;
  document.head.appendChild(style);

  loadDefaultCode();
  
  // Mode toggle button click handler
  const modeToggleButton = document.getElementById('mode-toggle-btn');
  const faucetButton = document.getElementById('faucet-btn');
  const modeText = document.getElementById('mode-text');
  const navContainer = document.getElementById('nav-container');
  const modeIndicator = document.getElementById('mode-indicator');
  
  // Initialize UI based on current mode (from localStorage)
  if (currentMode === 'exploration') {
    // In Exploration mode: show faucet and mode indicator
    if (faucetButton) {
      faucetButton.style.display = 'flex';
    }
    if (navContainer) {
      navContainer.classList.add('exploration-mode');
    }
    if (modeIndicator) {
      modeIndicator.style.display = 'block';
    }
  } else {
    // In Normal mode: hide faucet and mode indicator
    if (faucetButton) {
      faucetButton.style.display = 'none';
    }
    if (navContainer) {
      navContainer.classList.remove('exploration-mode');
    }
    if (modeIndicator) {
      modeIndicator.style.display = 'none';
    }
  }
  
  if (modeToggleButton) {
    modeToggleButton.addEventListener('click', async () => {
      const switchToMode = currentMode === 'normal' ? 'exploration' : 'normal';
      
      // Prepare alert message based on target mode
      let alertMessage = '';
      if (switchToMode === 'exploration') {
        
        alertMessage = ['Switching to Exploration Mode will:\n',
                      '• Revert the blockchain state',
                      '• Clear your attack history',
                      '• Disable history recording',
                      '• Enable the USDC Faucet',
                      'Continue?'].join('\n');
      } else {
        alertMessage = ['Switching to Normal Mode will:\n',
                      '• Revert the blockchain state',
                      '• Clear your attack history',
                      '• Enable history recording',
                      '• Disable the USDC Faucet',
                      'Continue?'].join('\n');
      }
      
      if (!confirm(alertMessage)) {
        return; // User cancelled
      }
      
      // Disable button during state change
      modeToggleButton.disabled = true;
      const originalText = modeText.textContent;
      modeText.textContent = 'Switching...';
      
      try {
        // Always revert state when switching modes
        const res = await fetch('/revert', { method: 'POST' });
        const data = await res.json();
        
        if (data.success) {
          // Update mode
          currentMode = switchToMode;
          
          // Save mode to localStorage to persist across page reloads
          localStorage.setItem('ctfMode', currentMode);
          
          // If entering Exploration mode, disable history recording
          if (currentMode === 'exploration') {
            const disableRes = await fetch('/disable-history', { method: 'POST' });
            const disableData = await disableRes.json();
            if (!disableData.success) {
              console.error('Error disabling history:', disableData.error);
            }
          } else {
            // If returning to Normal mode, re-enable history recording
            const enableRes = await fetch('/enable-history', { method: 'POST' });
            const enableData = await enableRes.json();
            if (!enableData.success) {
              console.error('Error enabling history:', enableData.error);
            }
          }
          
          // Update UI based on new mode
          if (currentMode === 'exploration') {
            // In Exploration mode: show faucet and mode indicator
            if (faucetButton) {
              faucetButton.style.display = 'flex';
            }
            if (navContainer) {
              navContainer.classList.add('exploration-mode');
            }
            if (modeIndicator) {
              modeIndicator.style.display = 'block';
            }
          } else {
            // In Normal mode: hide faucet and mode indicator
            if (faucetButton) {
              faucetButton.style.display = 'none';
            }
            if (navContainer) {
              navContainer.classList.remove('exploration-mode');
            }
            if (modeIndicator) {
              modeIndicator.style.display = 'none';
            }
          }
          
          // Refresh all UI elements without page reload
          await refreshAllUIElements();
          
          // Reset button text
          modeText.textContent = 'Change Mode';
        } else {
          alert('Failed to switch mode: ' + (data.error || 'Unknown error'));
          modeText.textContent = originalText;
        }
      }
       catch (err) {
        console.error('Error switching mode:', err);
        alert('An error occurred while switching mode.');
        modeText.textContent = originalText;
      } finally {
        modeToggleButton.disabled = false;
      }
    });
  }
  
  // Faucet button click handler (only available in exploration mode)
  if (faucetButton) {
    faucetButton.addEventListener('click', async () => {
      // No confirmation needed - user is already in exploration mode
      
      // Disable button during request
      faucetButton.disabled = true;
      const btnText = faucetButton.querySelector('.btn-text');
      const originalText = btnText ? btnText.textContent : 'Faucet';
      if (btnText) btnText.textContent = 'Processing...';
      
      try {
        const res = await fetch('/faucet', { method: 'POST' });
        const data = await res.json();
        if (data.success) {
          // Update the balance display
          await updateUserBalance();
          // Update the history count badge (will show as disabled)
          await updateHistoryCount();
        } else {
          alert('Faucet failed: ' + (data.error || 'Unknown error'));
        }
      } catch (err) {
        console.error('Error requesting faucet:', err);
        alert('An error occurred while requesting the faucet.');
      } finally {
        // Re-enable button
        faucetButton.disabled = false;
        if (btnText) btnText.textContent = originalText;
      }
    });
  }

  // Revert button click handler
  const revertButton = document.getElementById('revert-btn');
  if (revertButton) {
    revertButton.addEventListener('click', async () => {
      const confirmMessage = [
        'Are you sure you want to revert the blockchain state? This will:\n',
        '• Revert the blockchain state',
        '• Clear your attack history',
        'Continue?'
      ].join('\n');
      if (confirm(confirmMessage)){ 
        try {
          const res = await fetch('/revert', { method: 'POST' });
          const data = await res.json();
          if (data.success) {
            // Refresh all UI elements without page reload
            await refreshAllUIElements();
          } else {
            alert('Failed to revert state: ' + (data.error || 'Unknown error'));
          }
        } catch (err) {
          console.error('Error reverting state:', err);
          alert('An error occurred while reverting the blockchain state.');
        }
      }
    });
  }
});

setInterval(() => {
  const activeTab = document.querySelector(".tab-content.active").id;
  if (activeTab === "protocols") {
    updateTicketsTable();
    updateLotteryChallenges();
    updateAuctionsTable();
    updateAuctionVaultInfo();
    updateContractAddresses();
  }
}, 60000);

CodeMirror.defineSimpleMode("solidity", {
  start: [
    { regex: /\/\/.*/, token: "comment" },
    { regex: /\/\*[\s\S]*?\*\//, token: "comment" },
    { regex: /"(?:[^\\]|\\.)*?"/, token: "string" },
    { regex: /'(?:[^\\]|\\.)*?'/, token: "string" },
    { regex: /\b(?:pragma|import|contract|function|event|modifier|mapping|struct|enum|if|else|for|while|do|return|emit|require|revert|assembly)\b/, token: "keyword" },
    { regex: /\b(?:address|bool|string|bytes|bytes32|uint|uint256|uint8|int|int256|payable|memory|storage|public|private|external|internal|view|pure)\b/, token: "atom" },
    { regex: /\b\d+(\.\d+)?\b/, token: "number" },
    { regex: /[{}()\[\]]/, token: "bracket" },
    { regex: /[a-zA-Z_$][\w$]*/, token: "variable" }
  ],
  meta: { lineComment: "//" }
});

const editor = CodeMirror.fromTextArea(document.getElementById("AttackCode"), {
  mode: "solidity",
  theme: "dracula",
  lineNumbers: true,
  matchBrackets: true,
  autoCloseBrackets: true,
  extraKeys: { 
    "Ctrl-/": "toggleComment", 
    "Cmd-/": "toggleComment",
    "Ctrl-F": "findPersistent",
    "Cmd-F": "findPersistent",
    "Ctrl-G": "findNext",
    "Cmd-G": "findNext",
    "Shift-Ctrl-G": "findPrev",
    "Shift-Cmd-G": "findPrev",
    "Ctrl-H": "replace",
    "Cmd-Alt-F": "replace"
  }
});

async function loadDefaultCode() {
  try {
    const response = await fetch("/default.sol");
    if (!response.ok) {
      throw new Error("Failed to fetch default.sol: " + response.statusText);
    }
    const code = await response.text();
    editor.setValue(code);
  } catch (error) {
    console.error("Error loading default code:", error);
    editor.setValue("// Could not load default.sol\n");
  }
}

document.addEventListener("DOMContentLoaded", loadDefaultCode);
