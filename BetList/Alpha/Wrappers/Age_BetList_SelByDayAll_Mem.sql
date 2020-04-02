/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelByDayAll_Mem]
	@CustId			INT
	, @FromDate		SMALLDATETIME
	, @MoveBetsDay	SMALLDATETIME
	, @TransType	INT				= 0
	, @Error 		INT				= 0		OUTPUT
	, @ErrorMsg		NVARCHAR(250)	= ''	OUTPUT
AS

/*
	Created:
	Task: Bet List for Daily Statement
	DB: DBAGE.bodb02
	Original:Acc_BetListByDayAll_1
	Revisions:
		- 20081030@QuangVinh: Add more result for Horseracing,TransType: 0: all bets, 1: bets settled, 2: void and cancelled, 3: running and waiting
		- 20090326@Phuc: get indexname for FI
		- 20090407@Amy: Get refno for Mix parlay
						- Remove INNER JOIN bettype table for Mix parlay
		- 20090414@Amy: get more field betid for Casino
		- 20090416@Minh: remove indexName
		- 20090421@Henry: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@Henry: Change formula of commission
		- 20090528@Henry: get more result for Horse racing fix odds;Get more data from bettransm, bettransm14 for HR
		- 20090618@AnhPham: Remove 'Customer' table
		- 20090630@AnhPham: Remove 'creator' field from table variable and insert statement
		- 20090710@Phuc: unhide IP for TB currency.
		- 20090930@Phuc: Show the refunded tickets' status based on bettrans.status
		- 20091024@MinhNguyen: get modds, finalodds
		- 20100318@Jamie: Remove input param @transid and enhance checking the group of bet tickets
		- 20100610@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100902@Kiwi: Add IBCBet Bingo
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110113@Jamie: Put index hint on bettransm & bettransm14 
		- 20110114@Thien: Put index hint on bettrans/bettrans14
		- 20110408@Amy: Change function to get Odds value and showed odds type
		- 20110512@Johnson: Apply new arrange bettype
		- 20110620@Johnson: change column commission to playercomm
		- 20110725@Lukas: Get refund tickets when transtype = 1
		- 20110825@Sophia: Edit betID not hard code bettype = 87, and show BetID for every bettype. If Deadball (liveindicator = 0), web code will hide BetID
		- 20110826@Sophia: Add Bettype = 29, add column Actual_stake, show Betteam for System Parlay
		- 20110826@Jamie: Get modds as winning odds for system parlay
		- 20110829@Sophia: Get BetID for Parlay
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice, f_ShowOddsByBettype
		- 20120112@Sophia: Add showtime for Table - Shoe - Hand of LiveCasino
						- Add Sub table for Live Casino
		- 20120405@Hurri: Exclude bettype 72 and 23101 in the calculation of Casino
						- Get more data of P2P (bettype: 1000, 23102)
		- 20120309@Sophia: Not to use Checktime and SecAcceptFlag showing waiting or running status for Casino, Bingo, P2P, Outright, Mix parlay
		- 20120410@Hurri: change matchid 0 -> 1000 for bettype 1000
		- 20120426@Lukas: show transid of mainticket for all sub-tickets of system parlay
		- 20120502@Johnson: Get session id(betcheck) for bets list P2P
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120927@Sophia: Get comstatus
		- 20130225@Elodie: Add bet list of Virtual Horse Racing
		- 20130401@Lukas: fix bugs - wrong selected table
		- 20130705@Kathy: Update matchid for RnG Casino (71) and Bingo (73)
		- 20130820@Kathy: Apply Progressive Bonus: bettype 72 for Casino
		- 20140303@Elodie: Add Keno sport [Redmine:#12756]
		- 20141103@Dom: Apply sport bettype matrix
		- 20150209@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217 
		- 20150326@Cody: Remove RnG Casino Casino (71) and Bingo (73) for OutStanding value [Redmine: #15274]
		- 20150522@Bobby: Add GD product
		- 20150526@Bobby: Implement bet list core
		- 20150706@Bobby: #39097 - Fixing bug for showing Keno's bettype info
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion
		- 20150909@Kos: Fix bug not show CB ticket after clicking Grand Prize in Statement report
		- 20150910@Bobby: Enhance performence for SP core. Apply TVP for input parameters
		- 20160310@Kos: Don't support Deposit products
		- 20160519@Francis: Change to use inline function to enhance performance
		- 20170620@Kos: Add param @MoveBetsDay [#Redmine: 77280]
		- 20180201@Kos: Don't support Racing, Live Casino, RNG Casino (bettype 71, 72), Bingo, P2P, Cockfighting [#Redmine: 86086]
		- 20180323@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20181129@Kos: Enhance performance, don't use core anymore [#Redmine: 103577]
		- 20181227@Kos: Support E-Sports phase 2b [#Redmine: 106456]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 105585]
		- 20190506@Kos: Show match KO time for single ticket [Redmine: #112092]
		- 20190524@Kos: Support BetBuilder [Redmine: #106905]
		- 20190611@Kos: Support Card Club [Redmine: #107645]
					- Don't support Poker Games anymore
					- Remove param @Language
		- 20190722@Kos: Support new status Pending [#Redmine: 113142]
		- 20190829@Kos: Don't support inactive products anymore [Redmine: #119100]
		- 20191028@Kos: Show Running status for Marked tickets [Redmine: 122391]
		- 20191127@Kos: Hotfix - Oddsspread data type [Redmine: #124483]
		- 20191128@Kos: Support Spadegaming [Redmine: #122140]
		- 20191218@Kos: Support Virtual Games [Redmine: #124759]
		- 20200302@Kos: Support SA Gaming [Redmine: #128048]
		- 20200324@Kos: Support Sexy Gaming [Redmine: #130680]
		- 20200331@Kos: Support Saba.club [Redmine: #130769]		
		- 20200402@Kos: Support Table Games [Redmine: #129433]

	Param's Explanation:
		+ @TransType:
			1: Betting Statement
			2: VOID/Cancelled Bet
			3: Outstanding Bet
			4: Grand Prize of ONERnG Jackpot
*/

BEGIN
	SET NOCOUNT ON;

	-- Check SP Version
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Gather BettypeMatrix
	DECLARE @SportBettype TABLE ( ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	IF @TransType <> 4
	BEGIN
		-- Don't support Deposit products (Playtech Casino, AG Casino, Microgaming Live Casino, Macau, Microgaming RNG Casino, BetTrade, Cash Out, Saba Promotion)
		-- Don't support Racing, Live Casino, RNG Casino (bettype 71, 72), Bingo, P2P, Cockfighting, Exchange, Poker Games, Bullfighting, Lucky 3, Colossus Bets
		INSERT INTO @SportBettype
		SELECT ProductID, Bettype, EventType, SubProduct
		FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
		WHERE ProductID NOT IN (2, 4, 7, 9, 10, 11, 13, 14, 15, 17, 19, 25, 26, 30, 31, 33, 37)
			AND BetType NOT IN (901, 902, 903, 904, 71, 72)

		DELETE FROM @SportBettype
		WHERE ProductID = 6 AND SubProduct = ''
	END
	ELSE		-- Grand Prize of ONERnG Jackpot
	BEGIN
		INSERT INTO @SportBettype
		SELECT ProductID, Bettype, EventType, SubProduct
		FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
		WHERE ProductID = 6 AND SubProduct <> ''
	END

	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

	CREATE TABLE #MemBetTicket (
		TransId				BIGINT
		, RefNo				BIGINT
		, CustId			INT
		, Username			NVARCHAR(50)
		, SportType			SMALLINT
		, BetType			SMALLINT
		, BetId				BIGINT
		, BetTeam			NVARCHAR(20)
		, Hdp1				SMALLMONEY
		, Hdp2				SMALLMONEY
		, OddsType			TINYINT
		, OddsId			INT
		, Odds				MONEY
		, MOdds				MONEY
		, Stake				MONEY
		, Actual_Stake		MONEY
		, Status			NVARCHAR(10)
		, SettlementStatus	TINYINT
		, TransDate			DATETIME
		, WinLostDate		SMALLDATETIME
		, WinLost			MONEY
		, AWinLost			MONEY
		, MWinLost			MONEY
		, SWinLost			MONEY
		, PlayerComm		MONEY
		, Comm				MONEY
		, AComm				MONEY
		, SComm				MONEY
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, TPositionTaking	SMALLMONEY
		, ADiscount			SMALLMONEY
		, MDiscount			SMALLMONEY
		, SDiscount			SMALLMONEY
		, LiveIndicator		BIT
		, LiveHomeScore		SMALLINT
		, LiveAwayScore		SMALLINT
		, FinalHomeScore	SMALLINT
		, FinalAwayScore	SMALLINT
		, HtHomeScore		SMALLINT
		, HtAwayScore		SMALLINT
		, Ip				NVARCHAR(15)
		, LeagueId			INT
		, MatchId			INT
		, MatchCode			NVARCHAR(50)
		, Race				NVARCHAR(20)
		, EventDate			DATETIME
		, HomeId			INT
		, AwayId			INT
		, BetStatus			NVARCHAR(50)
		, IsNeutral			BIT
		, Placing			NVARCHAR(20)
		, ShowTime			NVARCHAR(50)
		, BetCheck			NVARCHAR(50)
		, ComStatus			NVARCHAR(20)
		, TransDesc			NVARCHAR(1000)
		, OddsSpread		MONEY
		, BetdaqId			BIGINT
		, ExtraInfo			VARCHAR(1000)
		, Currency			NVARCHAR(50)
	);

	DECLARE @Tickets TABLE (
		TransId			BIGINT
		, RefNo			BIGINT
		, WinLostDate	SMALLDATETIME
		, Product		VARCHAR(30)
	)

	DECLARE @temp_bettransX TABLE (
		RefNo				BIGINT
		, Odds				MONEY
		, Stake				MONEY
		, Actual_Stake		MONEY
		, Status			NVARCHAR(10)
		, WinLost			MONEY
		, AWinLost			MONEY
		, MWinLost			MONEY
		, SWinLost			MONEY
		, PlayerComm		MONEY
		, Comm				MONEY
		, AComm				MONEY
		, SComm				MONEY
		, APositiontaking	SMALLMONEY
		, MPositiontaking	SMALLMONEY
		, SPositiontaking	SMALLMONEY
		, TPositiontaking	SMALLMONEY
		, Discount			SMALLMONEY
		, ADiscount			SMALLMONEY
		, SDiscount			SMALLMONEY
		, OddsSpread		MONEY
	)

	DECLARE @BettransDetail TABLE (
		RefNo				BIGINT
		, Odds				MONEY
		, Stake				MONEY
		, Status			NVARCHAR(10)
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, BetType			SMALLINT
		, BetTeam			NVARCHAR(10)
		, TransDesc			VARCHAR(1000)
	)

	--Use Local variables to avoid bad params sniffing
	DECLARE @Date SMALLDATETIME

	SET @Date = @FromDate

	-- bettrans
	IF @FromDate > @MoveBetsDay
	BEGIN
		IF @TransType <> 4
		BEGIN
			INSERT INTO @Tickets (
				TransId,
				RefNo,
				WinLostDate,
				Product
			)
			SELECT
				b.transid,
				b.refno,
				b.winlostdate,
				CASE
					WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
					WHEN s.EventType = 0 AND s.ProductID = 6 THEN 'OneRNG'		-- RNG Casino
					WHEN s.EventType = 0 AND s.ProductID = 8 THEN 'Keno'
					WHEN s.EventType = 0 AND s.ProductID = 12 THEN 'GD'			-- Gold Deluxe
					WHEN s.EventType = 0 AND s.ProductID = 21 THEN 'AllBet'
					WHEN s.EventType = 0 AND s.ProductID = 22 THEN 'VB'			-- Macau Games
					WHEN s.EventType = 0 AND s.ProductID = 23 THEN 'NG2'
					WHEN s.EventType = 0 AND s.ProductID = 24 THEN 'FW'			-- Fishing World
					WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
					WHEN s.EventType = 0 AND s.ProductID = 28 THEN 'Lottery'
					WHEN s.EventType = 0 AND s.ProductID = 32 THEN 'PP'			-- Pragmatic Play Casino
					WHEN s.ProductID = 34					THEN 'CC'			-- Card Club
					WHEN s.ProductID = 36					THEN 'SG'			-- Spadegaming
					WHEN s.ProductID = 38					THEN 'VRG'			-- Virtual Games
					WHEN s.ProductID = 39					THEN 'SAG'			-- SA Gaming
					WHEN s.ProductID = 40					THEN 'TG'			-- Table Games
					WHEN s.ProductID = 42					THEN 'SBC'			-- Saba.club
					WHEN s.ProductID = 45					THEN 'SXG'			-- Sexy Gaming
					WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
					WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
					WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports:: sportsbook
					WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
					WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
					WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual sports:: racing
					ELSE 'Unknown'
				END AS Product
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
				AND (s.SubProduct NOT IN ('MG-SuperLive') OR b.StatusId NOT IN (0, 1))
				AND 1 = CASE
							WHEN @TransType = 1 AND b.statusID IN (103, 111, 112, 113) THEN 1
							WHEN @TransType = 2 AND b.statusID IN (101, 102) THEN 1
							WHEN @TransType = 3 AND b.statusID IN (0, 1) THEN 1
							WHEN @Date >= @Yesterday AND @TransType IN (1, 3)
								AND s.ProductID IN (6, 21, 22, 24, 32, 34, 36, 39, 42, 45) THEN 1 -- don't care status of casino's summary rows if >= yesterday
							ELSE 0
						END

			DELETE FROM @Tickets WHERE Product = 'Unknown'
			
			IF EXISTS (SELECT 1 FROM @Tickets)
			BEGIN
				IF @TransType = 1
				BEGIN
					-- bettransRnG
					IF EXISTS (SELECT 1 FROM @Tickets WHERE Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC') AND WinLostDate >= @Yesterday)
					BEGIN
						INSERT INTO @temp_bettransX
						SELECT
							c.TransId AS RefNo,
							CASE
								WHEN Product = 'OneRNG' THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
								ELSE 0
							END AS Odds,
							SUM(brng.stake) AS Stake,
							SUM(brng.actual_stake) AS Actual_Stake,
							CASE
								WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
								WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
								ELSE 'Draw'
							END AS Status,
							SUM(brng.winlost - brng.actual_stake) AS WinLost,
							SUM(brng.awinlost) AS AWinLost,
							SUM(brng.mwinlost) AS MWinLost,
							SUM(brng.swinlost) AS SWinLost,
							SUM(brng.playercomm) AS PlayerComm,
							SUM(brng.comm - brng.playercomm) AS Comm,
							SUM(brng.acomm - brng.comm) AS AComm,
							SUM(brng.scomm - brng.acomm) AS SComm,
							AVG(brng.APositiontaking) AS APositiontaking,
							AVG(brng.MPositiontaking) AS MPositiontaking,
							AVG(brng.SPositiontaking) AS SPositiontaking,
							AVG(brng.TPositiontaking) AS TPositiontaking,
							AVG(brng.discount) AS Discount,
							AVG(brng.adiscount) AS ADiscount,
							AVG(brng.sdiscount) AS SDiscount,
							CASE
								WHEN c.Product IN ('OneRNG') THEN ISNULL(SUM(brng.BetStake), 0)
								ELSE 0
							END AS OddsSpread
						FROM @Tickets AS c
							INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
						WHERE c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC')
							AND c.WinLostDate >= @Yesterday
							AND brng.statusID NOT IN (0, 1)
						GROUP BY
							c.TransId,
							c.Product
					END

					-- bettransLC
					IF EXISTS (SELECT 1 FROM @Tickets WHERE Product IN ('Allbet', 'SAG', 'SXG') AND WinLostDate >= @Yesterday)
					BEGIN
						INSERT INTO @temp_bettransX
						SELECT
							c.TransId AS RefNo,
							0 AS Odds,
							SUM(blc.stake) AS Stake,
							SUM(blc.actual_stake) AS Actual_Stake,
							CASE
								WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
								WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
								ELSE 'Draw'
							END AS Status,
							SUM(blc.winlost - blc.actual_stake) AS WinLost,
							SUM(blc.awinlost) AS AWinLost,
							SUM(blc.mwinlost) AS MWinLost,
							SUM(blc.swinlost) AS SWinLost,
							SUM(blc.playercomm) AS PlayerComm,
							SUM(blc.comm - blc.playercomm) AS Comm,
							SUM(blc.acomm - blc.comm) AS AComm,
							SUM(blc.scomm - blc.acomm) AS SComm,
							AVG(blc.APositiontaking) AS APositiontaking,
							AVG(blc.MPositiontaking) AS MPositiontaking,
							AVG(blc.SPositiontaking) AS SPositiontaking,
							AVG(blc.TPositiontaking) AS TPositiontaking,
							AVG(blc.discount) AS Discount,
							AVG(blc.adiscount) AS ADiscount,
							AVG(blc.sdiscount) AS SDiscount,
							0 AS OddsSpread
						FROM @Tickets AS c
							INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
						WHERE c.Product IN ('Allbet', 'SAG', 'SXG')
							AND c.WinLostDate >= @Yesterday
							AND blc.statusID NOT IN (0, 1)
						GROUP BY
							c.TransId,
							c.Product
					END
				END

				IF @TransType = 3
				BEGIN
					-- bettransRnG
					IF EXISTS (SELECT 1 FROM @Tickets WHERE Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC') AND WinLostDate >= @Yesterday)
					BEGIN
						INSERT INTO @temp_bettransX
						SELECT
							c.TransId AS RefNo,
							0 AS Odds,
							SUM(brng.stake) AS Stake,
							SUM(brng.actual_stake) AS Actual_Stake,
							'Running' AS Status,
							0 AS WinLost,
							0 AS AWinLost,
							0 AS MWinLost,
							0 AS SWinLost,
							0 AS PlayerComm,
							0 AS Comm,
							0 AS AComm,
							0 AS SComm,
							AVG(brng.APositiontaking) AS APositiontaking,
							AVG(brng.MPositiontaking) AS MPositiontaking,
							AVG(brng.SPositiontaking) AS SPositiontaking,
							AVG(brng.TPositiontaking) AS TPositiontaking,
							AVG(brng.discount) AS Discount,
							AVG(brng.adiscount) AS ADiscount,
							AVG(brng.sdiscount) AS SDiscount,
							0 AS OddsSpread
						FROM @Tickets AS c
							INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
						WHERE c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC')
							AND c.WinLostDate >= @Yesterday
							AND brng.statusID IN (0, 1)
						GROUP BY
							c.TransId,
							c.Product
					END

					-- bettransLC
					IF EXISTS (SELECT 1 FROM @Tickets WHERE Product IN ('Allbet', 'SAG', 'SXG') AND WinLostDate >= @Yesterday)
					BEGIN
						INSERT INTO @temp_bettransX
						SELECT
							c.TransId AS RefNo,
							0 AS Odds,
							SUM(blc.stake) AS Stake,
							SUM(blc.actual_stake) AS Actual_Stake,
							'Running' AS Status,
							0 AS WinLost,
							0 AS AWinLost,
							0 AS MWinLost,
							0 AS SWinLost,
							0 AS PlayerComm,
							0 AS Comm,
							0 AS AComm,
							0 AS SComm,
							AVG(blc.APositiontaking) AS APositiontaking,
							AVG(blc.MPositiontaking) AS MPositiontaking,
							AVG(blc.SPositiontaking) AS SPositiontaking,
							AVG(blc.TPositiontaking) AS TPositiontaking,
							AVG(blc.discount) AS Discount,
							AVG(blc.adiscount) AS ADiscount,
							AVG(blc.sdiscount) AS SDiscount,
							0 AS OddsSpread
						FROM @Tickets AS c
							INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
						WHERE c.Product IN ('Allbet', 'SAG', 'SXG')
							AND c.WinLostDate >= @Yesterday
							AND blc.statusID IN (0, 1)
						GROUP BY
							c.TransId,
							c.Product
					END
				END

				DELETE b
				FROM @Tickets AS b
				WHERE b.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'Allbet', 'SAG', 'SXG')
					AND b.Winlostdate >= @Yesterday
					AND NOT EXISTS (SELECT 1 FROM @temp_bettransX WHERE RefNo = b.TransId)

				INSERT INTO #MemBetTicket
				SELECT TransId = CASE
									WHEN c.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END 
					,RefNo = b.refno
					,CustId = b.custid
					,Username = b.username
					,SportType = CASE
									WHEN c.Product IN ('OneRNG', 'CC', 'SG', 'VRG', 'SAG', 'TG', 'SBC', 'SXG') THEN b.matchid
									WHEN c.Product = 'Keno' THEN 202
									WHEN c.Product = 'GD' THEN 255 -- Gold Deluxe
									WHEN c.Product = 'AllBet' THEN 211 -- AllBet
									WHEN c.Product = 'VB' THEN 212 -- Macau Games
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2501 AND 2539 THEN 213 -- NG2
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2541 AND 2579 THEN 214 -- NG2
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2581 AND 2619 THEN 215 -- NG2
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2621 AND 2659 THEN 216 -- NG2
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2681 AND 2699 THEN 218 -- NG2
									WHEN c.Product = 'FW' THEN 219 -- Fishing World
									WHEN c.Product = 'Lottery' THEN 220 -- Lottery
									WHEN c.Product = 'PP' THEN 248 -- Pragmatic Casino
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.sporttype
									WHEN c.Product IN ('Outright') THEN l.sporttype
									WHEN c.Product IN ('VR') THEN vr.SportType
									ELSE 0
								END -- parlay(s)
					,BetType = b.bettype
					,BetId = ISNULL(b.betid, 0)
					,BetTeam = CASE 
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2') THEN b.betteam
									ELSE ''	END 
					,Hdp1 = CASE 
								WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2') THEN b.hdp1 -- parlay(s), NG2
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.hdp1
								WHEN c.Product IN ('VR') THEN b.hdp1
								ELSE 0 END
					,Hdp2 = CASE 
								WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2') THEN b.hdp2 --parlay(s), NG2
								WHEN c.Product IN ('SB', 'VS', 'VS2') THEN b.hdp2
								WHEN c.Product IN ('VR') THEN b.hdp2
								ELSE 0 END
					,OddsType = CASE 
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'Keno') THEN b.oddstype
									ELSE 0 END
					,OddsId = b.oddsid
					,Odds = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.Odds IS NOT NULL THEN x.Odds
								WHEN c.Product IN ('Parlay', 'OneRNG', 'Keno', 'GD', 'NG2', 'ParlayVS2', 'Lottery', 'VRG', 'TG') THEN b.Odds
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.odds
								WHEN c.Product IN ('Outright') THEN b.odds
								WHEN c.Product IN ('VR') THEN b.odds
								ELSE 0 END
					,MOdds = CASE 
								WHEN c.Product IN ('Parlay', 'ParlayVS2')  THEN b.modds 
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.modds
								WHEN c.Product IN ('Outright') THEN b.modds
								WHEN c.Product IN ('VR') THEN b.modds
								ELSE 0 END
					,Stake = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'Allbet', 'SAG', 'SXG') AND x.Stake IS NOT NULL THEN x.Stake
								ELSE b.stake END
					,Actual_Stake = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'Allbet', 'SAG', 'SXG') AND x.Actual_Stake IS NOT NULL THEN x.Actual_Stake
									ELSE b.actual_stake END
					,Status = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'Allbet', 'SAG', 'SXG') AND x.status IS NOT NULL THEN x.status
								WHEN c.Product = 'SB' AND b.bettype NOT IN (9, 29)
									AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								WHEN b.bettype IN (9, 29, 2799) AND b.status = 'running' THEN
									CASE
										WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
													WHERE bm.custid = b.custid
														AND bm.refno = b.refno
														AND (bm.status = 'waiting'
															OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
											THEN 'Waiting'
										ELSE b.status
									END
								ELSE b.status
							END
					,SettlementStatus = CASE
											WHEN c.Product IN ('SB') THEN ISNULL(m.SettlementStatus, 0)
											ELSE 0
										END
					,TransDate = b.transdate
					,WinLostDate = b.winlostdate
					,WinLost = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.WinLost IS NOT NULL THEN x.WinLost
									ELSE b.winlost - b.actual_stake END
					,AWinLost = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.AWinLost IS NOT NULL THEN x.AWinLost
									ELSE b.awinLost END
					,MWinLost = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.MWinLost IS NOT NULL THEN x.MWinLost
									ELSE b.mwinLost END
					,SWinLost = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.SWinLost IS NOT NULL THEN x.SWinLost
									ELSE b.SwinLost END
					,PlayerComm = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.PlayerComm IS NOT NULL THEN x.PlayerComm
									ELSE b.playercomm END
					,Comm = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.Comm IS NOT NULL THEN x.Comm
								ELSE b.comm - b.playercomm END
					,AComm = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.AComm IS NOT NULL THEN x.AComm
								ELSE b.acomm - b.comm END
					,SComm = CASE
								WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.SComm IS NOT NULL THEN x.SComm
								ELSE b.scomm - b.acomm END
					,APositionTaking = CASE
											WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.APositiontaking IS NOT NULL THEN x.APositiontaking
											ELSE b.APositiontaking END
					,MPositionTaking = CASE
											WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.MPositiontaking IS NOT NULL THEN x.MPositiontaking
											ELSE b.MPositiontaking END
					,SPositionTaking = CASE
											WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.SPositiontaking IS NOT NULL THEN x.SPositiontaking
											ELSE b.SPositiontaking END
					,TPositionTaking = CASE
											WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.TPositiontaking IS NOT NULL THEN x.TPositiontaking
											ELSE b.TPositiontaking END
					,ADiscount = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.discount IS NOT NULL THEN x.discount
									WHEN c.Product IN ('Lucky3') THEN 0
									ELSE b.discount END
					,MDiscount = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SAG', 'SBC', 'SXG') AND x.adiscount IS NOT NULL THEN x.adiscount
									WHEN c.Product IN ('Lucky3') THEN 0
									ELSE b.adiscount END
					,SDiscount = CASE
									WHEN c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'Allbet', 'SAG', 'SXG') AND x.sdiscount IS NOT NULL THEN x.sdiscount
									ELSE b.sdiscount END
					,LiveIndicator = CASE 
										WHEN c.Product IN ('Parlay') THEN b.Liveindicator 
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.liveindicator
										ELSE 0 END
					,LiveHomeScore = CASE 
										WHEN c.Product IN ('Parlay', 'NG2') THEN b.Livehomescore 
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.livehomescore
										WHEN c.Product IN ('Outright') THEN b.livehomescore
										WHEN c.Product IN ('VR') THEN b.livehomescore
										ELSE 0 END
					,LiveAwayScore = CASE 
										WHEN c.Product IN ('Parlay') THEN b.Liveawayscore 
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.liveawayscore
										WHEN c.Product IN ('Outright') THEN b.liveawayscore
										WHEN c.Product IN ('VR') THEN b.liveawayscore
										ELSE 0 END
					,FinalHomeScore = CASE
											WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.finalhomescore
											ELSE 0 END
					,FinalAwayScore = CASE
											WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.finalawayscore
											ELSE 0 END
					,HtHomeScore = CASE
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.hthomescore
										ELSE 0 END
					,HtAwayScore = CASE
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.htawayscore
										ELSE 0 END
					,Ip = b.ip
					,LeagueId = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.leagueid
									WHEN c.Product IN ('Outright') THEN o.leagueid
									WHEN c.Product IN ('VR') THEN vr.LeagueID
									ELSE 0 END
					,MatchId = CASE
									WHEN c.Product IN ('GD') THEN 255
									WHEN c.Product IN ('NG2') THEN b.betdaqid
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchid
									WHEN c.Product IN ('Outright') THEN o.orid
									WHEN c.Product IN ('VR') THEN b.matchid
									ELSE 0 END
					,MatchCode = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchcode
									WHEN c.Product IN ('Outright') THEN o.matchcode
									WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE '' END
					,Race = CASE
									WHEN c.Product IN ('Outright') THEN o.groupmatch
									WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
									ELSE '' END
					,EventDate = CASE
									WHEN c.Product = 'SB' THEN m.GlobalShowTime
									WHEN c.Product IN ('NG', 'VS', 'VS2') THEN m.eventdate
									WHEN c.Product IN ('Outright') THEN o.eventdate
									WHEN c.Product IN ('VR') THEN vo.EventDate
									ELSE b.winlostdate END
					,HomeId = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.homeid
									WHEN c.Product IN ('Outright') THEN o.teamid
									WHEN c.Product IN ('VR') THEN vo.RacerID
									ELSE 0 END
					,AwayId = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.awayid
									ELSE 0 END
					,BetStatus = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.betstatus
									ELSE '' END
					,IsNeutral = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0 END
					,Placing = CASE
									WHEN c.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
									ELSE '' END
					,ShowTime = CASE
									WHEN c.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN c.Product IN ('SB', 'NG') THEN ISNULL(m.showtime, '')
									WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE '' END
					,BetCheck = CASE 
									WHEN c.Product IN ('GD', 'VRG') THEN ISNULL(b.betcheck, '')
									WHEN c.Product IN ('Parlay', 'ParlayVS2') THEN ISNULL(b.betcheck, '')
									WHEN c.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
									WHEN c.Product IN ('SB') THEN ISNULL(b.betcheck, '')
									ELSE '' 
								END
					,ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END
					,TransDesc = CASE
									WHEN c.Product IN ('OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'FW', 'Lottery', 'PP', 'VRG', 'TG') THEN b.transdesc
									WHEN c.Product IN ('SB', 'VS2') THEN ISNULL(b.transdesc, '')
									ELSE '' END
					,OddsSpread = CASE
									WHEN c.Product IN ('OneRNG') THEN ISNULL(b.oddsspread, 0)
									WHEN c.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
									ELSE 0 END
					,BetdaqId = -1
					,ExtraInfo = CASE
									WHEN c.Product IN ('SB') THEN ISNULL(b.ExtraInfo, '')
									ELSE '' END
					,Currency = b.currencyname
				FROM @Tickets AS c
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.transid = c.transid
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON c.Product IN ('SB', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
					LEFT JOIN @temp_bettransX AS x ON c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'Allbet', 'SAG', 'SXG') AND c.Winlostdate >= @Yesterday AND x.RefNo = c.transid
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON c.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON c.Product IN ('Outright') AND o.leagueID = l.leagueID
					LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON c.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON c.Product IN ('VR') AND vr.EventID = vo.EventID

				-- Virtual Sports Racing
				INSERT INTO @BettransDetail
				SELECT RefNo = bm.refno
					,Odds = bm.odds
					,Stake = bm.stake
					,Status = bm.status
					,APositionTaking = bm.apositiontaking
					,MPositionTaking = bm.mpositiontaking
					,SPositionTaking = bm.spositiontaking
					,BetType = bm.bettype
					,BetTeam = bm.betteam
					,TransDesc = ''
				FROM @Tickets AS c
					INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON c.RefNo = bm.refno
				WHERE c.Product = 'VR' AND bm.custid = @CustId
	
				UNION ALL -- Gold Deluxe
				SELECT RefNo = bg.refno
					,Odds = bg.odds
					,Stake = bg.stake
					,Status = bg.status
					,APositionTaking = bg.apositiontaking
					,MPositionTaking = bg.mpositiontaking
					,SPositionTaking = bg.spositiontaking
					,BetType = bg.bettype
					,BetTeam = bg.betteam
					,TransDesc = bg.transdesc
				FROM @Tickets AS c
					INNER JOIN dbo.bettransg AS bg WITH (NOLOCK) ON c.TransId = bg.refno
				WHERE c.Product = 'GD' AND bg.custid = @CustId
			END

			IF @TransType = 3
			BEGIN
				DELETE FROM @Tickets

				-- translog
				INSERT INTO @Tickets (
					TransId,
					RefNo,
					WinLostDate,
					Product
				)
				SELECT
					b.translogid AS TransId,
					b.translogid AS RefNo,
					b.winlostdate,
					CASE
						WHEN s.BetType BETWEEN 801 AND 899 THEN 'MG'	-- Metric Gaming
						WHEN s.ProductID = 8 THEN 'Keno'
						WHEN s.ProductID = 12 THEN 'GD'			-- Gold Deluxe
						WHEN s.ProductID = 28 THEN 'Lottery'
						WHEN s.ProductID = 38 THEN 'VRG'		-- Virtual Games
						WHEN s.ProductID = 40 THEN 'TG'			-- Table Games
						ELSE 'Unknown'
					END AS Product
				FROM dbo.translog AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON b.gameID = s.Bettype
				WHERE b.custid = @CustId
					AND b.winlostdate = @Date
					AND b.statusID IN (0, 1)
					AND (s.ProductID IN (8, 12, 28, 38, 40)
						OR s.Bettype BETWEEN 801 AND 899)

				DELETE FROM @Tickets WHERE Product = 'Unknown'

				IF EXISTS (SELECT 1 FROM @Tickets)
				BEGIN
					INSERT INTO #MemBetTicket
					SELECT TransId = b.translogid
						,RefNo = b.translogid
						,CustId = b.custid
						,Username = b.username
						,SportType = CASE
										WHEN c.Product = 'Keno' THEN 202
										WHEN c.Product = 'GD' THEN 255 -- Gold Deluxe 
										WHEN c.Product = 'Lottery' THEN 220 -- Lottery
										WHEN c.Product = 'MG' THEN m.sporttype
										WHEN c.Product IN ('VRG', 'TG') THEN b.productID
										ELSE 0
									END
						,BetType = b.gameID
						,BetId = 0
						,BetTeam = ''
						,Hdp1 = 0
						,Hdp2 = 0
						,OddsType = CASE 
										WHEN c.Product IN ('MG') THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
										ELSE 0
									END
						,OddsId = 0
						,Odds = b.odds
						,MOdds = 0
						,Stake = b.stake
						,Actual_Stake = b.actual_stake
						,Status = b.status
						,SettlementStatus = 0
						,TransDate = b.transdate
						,WinLostDate = b.winlostdate
						,WinLost = 0
						,AWinLost = 0
						,MWinLost = 0
						,SWinLost = 0
						,PlayerComm = 0
						,Comm = 0
						,AComm = 0
						,SComm = 0
						,APositionTaking = b.APositiontaking
						,MPositionTaking = b.MPositiontaking
						,SPositionTaking = b.SPositiontaking
						,TPositionTaking = b.TPositiontaking
						,ADiscount = b.discount
						,MDiscount = b.adiscount
						,SDiscount = b.sdiscount
						,LiveIndicator = 0
						,LiveHomeScore = 0
						,LiveAwayScore = 0
						,FinalHomeScore = CASE
												WHEN c.Product IN ('MG') THEN m.finalhomescore
												ELSE 0 END
						,FinalAwayScore = CASE
												WHEN c.Product IN ('MG') THEN m.finalawayscore
												ELSE 0 END
						,HtHomeScore = CASE
											WHEN c.Product IN ('MG') THEN m.hthomescore
											ELSE 0 END
						,HtAwayScore = CASE
											WHEN c.Product IN ('MG') THEN m.htawayscore
											ELSE 0 END
						,Ip = b.ip
						,LeagueId = CASE
										WHEN c.Product IN ('MG') THEN m.leagueid
										ELSE 0 END
						,MatchId = CASE
										WHEN c.Product IN ('GD') THEN 255
										WHEN c.Product IN ('MG') THEN m.matchid
										ELSE 0 END
						,MatchCode = CASE
										WHEN c.Product IN ('MG') THEN m.matchcode
										ELSE '' END
						,Race = ''
						,EventDate = CASE
										WHEN c.Product IN ('MG') THEN m.GlobalShowTime
										ELSE b.winlostdate END
						,HomeId = CASE
										WHEN c.Product IN ('MG') THEN m.homeid
										ELSE 0 END
						,AwayId = CASE
										WHEN c.Product IN ('MG') THEN m.awayid
										ELSE 0 END
						,BetStatus = CASE
										WHEN c.Product IN ('MG') THEN m.betstatus
										ELSE '' END
						,IsNeutral = CASE
										WHEN c.Product IN ('MG') THEN ISNULL(m.IsNeutral, 0)
										ELSE 0 END
						,Placing = ''
						,ShowTime = CASE
										WHEN c.Product IN ('MG') THEN ISNULL(m.showtime, '')
										ELSE '' END
						,BetCheck = CASE 
										WHEN c.Product IN ('GD', 'VRG') THEN b.Gameid3rd
										WHEN c.Product IN ('Keno') THEN ISNULL(b.custom2, '')
										ELSE '' END
						,ComStatus = 0
						,TransDesc = CASE
										WHEN c.Product IN ('MG', 'Keno', 'Lottery', 'VRG', 'TG') THEN b.transdesc
										ELSE '' END
						,OddsSpread = 0
						,BetdaqId = -1
						,ExtraInfo = ''
						,Currency = b.currencyname
					FROM @Tickets AS c
						INNER JOIN dbo.translog AS b WITH (NOLOCK) ON b.translogid = c.TransId
						LEFT JOIN dbo.match AS m WITH (NOLOCK) ON c.Product IN ('MG') AND b.eventid = m.matchid

					-- Get detail ticket
					-- Gold Deluxe
					INSERT INTO @BettransDetail
					SELECT RefNo = bg.refno
						,Odds = bg.odds
						,Stake = bg.stake
						,Status = bg.status
						,APositionTaking = bg.apositiontaking
						,MPositionTaking = bg.mpositiontaking
						,SPositionTaking = bg.spositiontaking
						,BetType = bg.bettype
						,BetTeam = bg.betteam
						,TransDesc = bg.transdesc
					FROM @Tickets AS c
						INNER JOIN dbo.bettransg AS bg WITH (NOLOCK) ON c.transid = bg.refno
					WHERE c.Product = 'GD' AND bg.custid = @CustId
				END
			END
		END
		ELSE	-- Grand Prize
		BEGIN
			INSERT INTO @Tickets (
				TransId,
				RefNo,
				WinLostDate,
				Product
			)
			SELECT
				b.transid,
				b.RefNo,
				b.winlostdate,
				'OneRNG' AS Product
			FROM dbo.bettransRnG AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.gameID = s.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
				AND b.statusID IN (111, 112, 113)
				AND s.ProductID = 6
				AND EXISTS (	SELECT 1
								FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
								WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))

			IF @@ROWCOUNT > 0
			BEGIN
				INSERT INTO #MemBetTicket
				SELECT TransId = b.transid
					,RefNo = b.refno
					,CustId = b.custid
					,Username = b.username
					,SportType = b.productID
					,BetType = b.gameID
					,BetId = 0
					,BetTeam = ''
					,Hdp1 = 0
					,Hdp2 = 0
					,OddsType =0
					,OddsId = 0
					,Odds = b.odds
					,MOdds = 0
					,Stake = b.stake
					,Actual_Stake = b.actual_stake
					,Status = b.status
					,SettlementStatus = 0
					,TransDate = b.transdate
					,WinLostDate = b.winlostdate
					,WinLost = b.winlost - b.actual_stake
					,AWinLost = b.awinLost
					,MWinLost = b.mwinLost
					,SWinLost = b.swinLost
					,PlayerComm = b.playercomm
					,Comm = b.comm - b.playercomm
					,AComm = b.acomm - b.comm
					,SComm = b.scomm - b.acomm
					,APositionTaking = b.APositiontaking
					,MPositionTaking = b.MPositiontaking
					,SPositionTaking = b.SPositiontaking
					,TPositionTaking = b.TPositiontaking
					,ADiscount = b.discount
					,MDiscount = b.adiscount
					,SDiscount = b.sdiscount
					,LiveIndicator = 0
					,LiveHomeScore = 0
					,LiveAwayScore = 0
					,FinalHomeScore = 0
					,FinalAwayScore = 0
					,HtHomeScore = 0
					,HtAwayScore = 0
					,Ip = b.ip
					,LeagueId = 0
					,MatchId = 0
					,MatchCode = 0
					,Race = ''
					,EventDate = ''
					,HomeId = 0
					,AwayId = 0
					,BetStatus =''
					,IsNeutral = 0
					,Placing = ''
					,ShowTime = ''
					,BetCheck = b.TranId3rd
					,ComStatus = '0'
					,TransDesc = ISNULL(b.transdesc, '')
					,OddsSpread = 0
					,BetdaqId = ISNULL(b.RefNo2, -1)
					,ExtraInfo = ''
					,Currency = b.currencyname
				FROM @Tickets AS c
					INNER JOIN dbo.bettransRnG AS b WITH (NOLOCK) ON b.transid = c.transid
			END
		END
	END

	-- bettrans14
	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @TransType <> 4
		BEGIN
			INSERT INTO @Tickets (
				TransId,
				RefNo,
				WinLostDate,
				Product
			)
			SELECT
				b.transid,
				b.refno,
				b.winlostdate,
				CASE
					WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
					WHEN s.EventType = 0 AND s.ProductID = 6 THEN 'OneRNG'		-- RNG Casino
					WHEN s.EventType = 0 AND s.ProductID = 8 THEN 'Keno'
					WHEN s.EventType = 0 AND s.ProductID = 12 THEN 'GD'			-- Gold Deluxe
					WHEN s.EventType = 0 AND s.ProductID = 21 THEN 'AllBet'
					WHEN s.EventType = 0 AND s.ProductID = 22 THEN 'VB'			-- Macau Games
					WHEN s.EventType = 0 AND s.ProductID = 23 THEN 'NG2'
					WHEN s.EventType = 0 AND s.ProductID = 24 THEN 'FW'			-- Fishing World
					WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
					WHEN s.EventType = 0 AND s.ProductID = 28 THEN 'Lottery'
					WHEN s.EventType = 0 AND s.ProductID = 32 THEN 'PP'			-- Pragmatic Play Casino
					WHEN s.ProductID = 34					THEN 'CC'			-- Card Club
					WHEN s.ProductID = 36					THEN 'SG'			-- Spadegaming
					WHEN s.ProductID = 38					THEN 'VRG'			-- Virtual Games
					WHEN s.ProductID = 39					THEN 'SAG'			-- SA Gaming
					WHEN s.ProductID = 40					THEN 'TG'			-- Table Games
					WHEN s.ProductID = 42					THEN 'SBC'			-- Saba.club
					WHEN s.ProductID = 45					THEN 'SXG'			-- Sexy Gaming
					WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
					WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
					WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports:: sportsbook
					WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
					WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
					WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual sports:: racing
					ELSE 'Unknown'
				END AS Product
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
				AND 1 = CASE
							WHEN @TransType = 1 AND b.statusID IN (103, 111, 112, 113) THEN 1
							WHEN @TransType = 2 AND b.statusID IN (101, 102) THEN 1
						END

			DELETE FROM @Tickets WHERE Product = 'Unknown'

			IF EXISTS (SELECT 1 FROM @Tickets)
			BEGIN
				INSERT INTO #MemBetTicket
				SELECT TransId = CASE WHEN c.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid END 
					,RefNo = b.refno
					,CustId = b.custid
					,Username = b.username
					,SportType = CASE
									WHEN c.Product IN ('OneRNG', 'CC', 'SG', 'VRG', 'SAG', 'TG', 'SBC', 'SXG') THEN b.matchid
									WHEN c.Product = 'Keno' THEN 202
									WHEN c.Product = 'GD' THEN 255 -- Gold Deluxe 
									WHEN c.Product = 'AllBet' THEN 211 -- AllBet
									WHEN c.Product = 'VB' THEN 212 -- Macau Games
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2501 AND 2539 THEN 213 -- NG2
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2541 AND 2579 THEN 214 -- NG2
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2581 AND 2619 THEN 215 -- NG2
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2621 AND 2659 THEN 216 -- NG2
									WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2681 AND 2699 THEN 218 -- NG2
									WHEN c.Product = 'FW' THEN 219 -- Fishing World
									WHEN c.Product = 'Lottery' THEN 220 -- Lottery
									WHEN c.Product = 'PP' THEN 248 -- Pragmatic Casino
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.sporttype
									WHEN c.Product IN ('Outright') THEN l.sporttype
									WHEN c.Product IN ('VR') THEN vr.SportType
									ELSE 0 END -- parlay(s)
					,BetType = b.bettype
					,BetId = ISNULL(b.betid, 0)
					,BetTeam = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2') THEN b.betteam
									ELSE ''	END 
					,Hdp1 = CASE
								WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2') THEN b.hdp1 -- parlay(s), NG2
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.hdp1
								WHEN c.Product IN ('VR') THEN b.hdp1
								ELSE 0 END
					,Hdp2 = CASE
								WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2') THEN b.hdp2 --parlay(s), NG2
								WHEN c.Product IN ('SB', 'VS', 'VS2') THEN b.hdp2
								WHEN c.Product IN ('VR') THEN b.hdp2
								ELSE 0 END
					,OddsType = CASE 
									WHEN c.Product IN ('Keno') THEN b.OddsType -- Keno
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.oddstype
									ELSE 0 END
					,OddsId = b.oddsid
					,Odds = CASE 
								WHEN c.Product IN ('Parlay', 'OneRNG', 'Keno', 'GD', 'NG2', 'ParlayVS2', 'Lottery', 'VRG', 'TG') THEN b.Odds
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.odds
								WHEN c.Product IN ('Outright') THEN b.odds
								WHEN c.Product IN ('VR') THEN b.odds
								ELSE 0 END
					,MOdds = CASE 
								WHEN c.Product IN ('Parlay', 'ParlayVS2')  THEN b.modds 
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.modds
								WHEN c.Product IN ('Outright') THEN b.modds
								WHEN c.Product IN ('VR') THEN b.modds
								ELSE 0 END
					,Stake = b.stake
					,Actual_Stake = b.actual_stake
					,Status = b.status
					,SettlementStatus = 0
					,TransDate = b.transdate
					,WinLostDate = b.winlostdate
					,WinLost = b.winlost - b.actual_stake
					,AWinLost = b.awinLost
					,MWinLost = b.mwinLost
					,SWinLost = b.swinLost
					,PlayerComm = b.playercomm
					,Comm = b.comm - b.playercomm
					,AComm = b.acomm - b.comm
					,SComm = b.scomm - b.acomm
					,APositionTaking = b.APositiontaking
					,MPositionTaking = b.MPositiontaking
					,SPositionTaking = b.SPositiontaking
					,TPositionTaking = b.TPositiontaking
					,ADiscount = b.discount
					,MDiscount = b.adiscount
					,SDiscount = b.sdiscount
					,LiveIndicator = CASE 
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay') THEN b.liveindicator
										ELSE 0 END
					,LiveHomeScore = CASE 
										WHEN c.Product IN ('Parlay', 'NG2') THEN b.livehomescore 
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.livehomescore
										WHEN c.Product IN ('Outright') THEN b.livehomescore
										WHEN c.Product IN ('VR') THEN b.livehomescore
										ELSE 0 END
					,LiveAwayScore = CASE 
										WHEN c.Product IN ('Parlay') THEN b.Liveawayscore 
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.liveawayscore
										WHEN c.Product IN ('Outright') THEN b.liveawayscore
										WHEN c.Product IN ('VR') THEN b.liveawayscore
										ELSE 0 END
					,FinalHomeScore = CASE
											WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.finalhomescore
											ELSE 0 END
					,FinalAwayScore = CASE
											WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.finalawayscore
											ELSE 0 END
					,HtHomeScore = CASE
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.hthomescore
										ELSE 0 END
					,HtAwayScore = CASE
										WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.htawayscore
										ELSE 0 END
					,Ip = b.ip
					,LeagueId = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.leagueid
									WHEN c.Product IN ('Outright') THEN o.leagueid
									WHEN c.Product IN ('VR') THEN vr.LeagueID
									ELSE 0 END
					,MatchId = CASE
									WHEN c.Product IN ('GD') THEN 255
									WHEN c.Product IN ('NG2') THEN b.betdaqid
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchid
									WHEN c.Product IN ('Outright') THEN o.orid
									WHEN c.Product IN ('VR') THEN b.matchid
									ELSE 0 END
					,MatchCode = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchcode
									WHEN c.Product IN ('Outright') THEN o.matchcode
									WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE '' END
					,Race = CASE
									WHEN c.Product IN ('Outright') THEN o.groupmatch
									WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
									ELSE '' END
					,EventDate = CASE
									WHEN c.Product = 'SB' THEN m.globalshowtime
									WHEN c.Product IN ('NG', 'VS', 'VS2') THEN m.eventdate
									WHEN c.Product IN ('Outright') THEN o.eventdate
									WHEN c.Product IN ('VR') THEN vo.EventDate
									ELSE b.winlostdate END
					,HomeId = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'Lucky3', 'VS2') THEN m.homeid
									WHEN c.Product IN ('Outright') THEN o.teamid
									WHEN c.Product IN ('VR') THEN vo.RacerID
									ELSE 0 END
					,AwayId = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.awayid
									ELSE 0 END
					,BetStatus = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.betstatus
									ELSE '' END
					,IsNeutral = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0 END
					,Placing = CASE
									WHEN c.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
									ELSE '' END
					,ShowTime = CASE
									WHEN c.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN c.Product IN ('SB', 'NG') THEN ISNULL(m.showtime, '')
									WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE '' END
					,BetCheck = CASE 
									WHEN c.Product IN ('GD', 'VRG') THEN ISNULL(b.betcheck, '')
									WHEN c.Product IN ('Parlay', 'ParlayVS2') THEN ISNULL(b.betcheck, '')
									WHEN c.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
									WHEN c.Product IN ('SB') THEN ISNULL(b.betcheck, '')
									ELSE '' END
					,ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END
					,TransDesc = CASE
									WHEN c.Product IN ('OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'FW', 'Lottery', 'PP', 'VRG', 'TG') THEN b.transdesc	
									WHEN c.Product IN ('SB', 'VS2') THEN ISNULL(b.transdesc, '')
									ELSE '' END
					,OddsSpread = CASE
									WHEN c.Product IN ('OneRNG') THEN ISNULL(b.oddsspread, 0)
									WHEN c.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
									ELSE 0 END
					,BetdaqId = -1
					,ExtraInfo = CASE
									WHEN c.Product IN ('SB') THEN ISNULL(b.ExtraInfo, '')
									ELSE '' END	
					,Currency = b.currencyname
				FROM @Tickets AS c
					INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK) ON b.transid = c.transid
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON c.Product IN ('SB', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON c.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON c.Product IN ('Outright') AND o.leagueID = l.leagueID
					LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON c.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON c.Product IN ('VR') AND vr.EventID = vo.EventID

				-- Virtual Sports Racing
				INSERT INTO @BettransDetail
				SELECT RefNo = bm.refno
					,Odds = bm.odds
					,Stake = bm.stake
					,Status = bm.status
					,APositionTaking = bm.apositiontaking
					,MPositionTaking = bm.mpositiontaking
					,SPositionTaking = bm.spositiontaking
					,BetType = bm.bettype
					,BetTeam = bm.betteam
					,TransDesc = ''
				FROM @Tickets AS c
					INNER JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON c.RefNo = bm.refno
				WHERE c.Product = 'VR' AND bm.custid = @CustId
	
				UNION ALL -- Gold Deluxe
				SELECT RefNo = bg.refno
					,Odds = bg.odds
					,Stake = bg.stake
					,Status = bg.status
					,APositionTaking = bg.apositiontaking
					,MPositionTaking = bg.mpositiontaking
					,SPositionTaking = bg.spositiontaking
					,BetType = bg.bettype
					,BetTeam = bg.betteam
					,TransDesc = bg.transdesc
				FROM @Tickets AS c
					INNER JOIN dbo.bettransg14 AS bg WITH (NOLOCK) ON c.TransId = bg.refno
				WHERE c.Product = 'GD' AND bg.custid = @CustId
			END
		END
		ELSE	-- Grand Prize
		BEGIN
			INSERT INTO @Tickets (
				TransId,
				RefNo,
				WinLostDate,
				Product
			)
			SELECT
				b.transid,
				b.refno,
				b.winlostdate,
				'OneRNG' AS Product
			FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.gameID = s.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @Date
				AND b.statusID IN (111, 112, 113)
				AND s.ProductID = 6
				AND EXISTS (	SELECT 1
								FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
								WHERE pt.refno = b.transid AND pt.PayoutStatus IN ('Completed', 'Expired'))

			IF @@ROWCOUNT > 0
			BEGIN
				INSERT INTO #MemBetTicket
				SELECT TransId = b.transid
					,RefNo = b.refno
					,CustId = b.custid
					,Username = b.username
					,SportType = b.productID
					,BetType = b.gameID
					,BetId = 0
					,BetTeam = ''
					,Hdp1 = 0
					,Hdp2 = 0
					,OddsType =0
					,OddsId = 0
					,Odds = b.odds
					,MOdds = 0
					,Stake = b.stake
					,Actual_Stake = b.actual_stake
					,Status = b.status
					,SettlementStatus = 0
					,TransDate = b.transdate
					,WinLostDate = b.winlostdate
					,WinLost = b.winlost - b.actual_stake
					,AWinLost = b.awinLost
					,MWinLost = b.mwinLost
					,SWinLost = b.swinLost
					,PlayerComm = b.playercomm
					,Comm = b.comm - b.playercomm
					,AComm = b.acomm - b.comm
					,SComm = b.scomm - b.acomm
					,APositionTaking = b.APositiontaking
					,MPositionTaking = b.MPositiontaking
					,SPositionTaking = b.SPositiontaking
					,TPositionTaking = b.TPositiontaking
					,ADiscount = b.discount
					,MDiscount = b.adiscount
					,SDiscount = b.sdiscount
					,LiveIndicator = 0
					,LiveHomeScore = 0
					,LiveAwayScore = 0
					,FinalHomeScore = 0
					,FinalAwayScore = 0
					,HtHomeScore = 0
					,HtAwayScore = 0
					,Ip = b.ip
					,LeagueId = 0
					,MatchId = 0
					,MatchCode = 0
					,Race = ''
					,EventDate = ''
					,HomeId = 0
					,AwayId = 0
					,BetStatus =''
					,IsNeutral = 0
					,Placing = ''
					,ShowTime = ''
					,BetCheck = b.TranId3rd
					,ComStatus = '0'
					,TransDesc = ISNULL(b.transdesc, '')
					,OddsSpread = 0
					,BetdaqId = ISNULL(b.RefNo2, -1)
					,ExtraInfo = ''
					,Currency = b.currencyname
				FROM @Tickets AS c
					INNER JOIN dbo.bettransRnG14 AS b WITH (NOLOCK) ON b.transid = c.transid
			END
		END
	END

	SELECT *
	FROM #MemBetTicket
	ORDER BY 1 DESC

	-- OUTPUT ticket detail
	SELECT *
	FROM @BettransDetail
	ORDER BY RefNo DESC

	DROP TABLE #MemBetTicket
END
GO


GRANT EXECUTE ON [dbo].[Age_BetList_SelByDayAll_Mem] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelByDayAll_Mem] TO [bodbDownlineNetView] AS [dbo]
GO
