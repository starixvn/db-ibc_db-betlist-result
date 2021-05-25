/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_CustomerList_Mem]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(10)		= '',
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@Sort			VARCHAR(50)		= 'TransDate ASC',
	-- check for showing product
	@ShowSB			BIT	= 0,	-- Sportsbook
	@ShowBA			BIT	= 0,	-- BA
	@ShowNG			BIT	= 0,	-- Number Game
	@ShowVS			BIT	= 0,	-- Virtual Sports
	@ShowCS			BIT	= 0,	-- RNG Casino
	@ShowKN			BIT	= 0,	-- Keno
	@ShowCB			BIT	= 0,	-- Colossus Bets
	@ShowAGC		BIT	= 0,	-- AG Casino
	@ShowAB			BIT	= 0,	-- AllBet
	@ShowVB			BIT	= 0,	-- Voidbridge
	@ShowFW			BIT	= 0,	-- Fishing World
	@ShowVS2		BIT	= 0,	-- Betradar Virtual Sports
	@ShowLT			BIT	= 0,	-- Lottery
	@ShowPP			BIT	= 0,	-- Pragmatic Casino
	@ShowCC			BIT	= 0,	-- Card Club
	@ShowSG			BIT	= 0,	-- Spadegaming
	@ShowVRG		BIT	= 0,	-- Virtual Games
	@ShowSAG		BIT = 0,	-- SA Gaming
	@ShowTG			BIT	= 0,	-- Table Games
	@ShowSBC		BIT	= 0,	-- Saba.club
	@ShowI4D		BIT	= 0,	-- Indo 4D
	@ShowSXG		BIT	= 0,	-- Sexy Gaming
	@ShowPGS		BIT	= 0,	-- PG Soft
	@ShowJK			BIT	= 0,	-- Joker
	@ShowGDG		BIT	= 0,	-- GDG
	@ShowSLT		BIT	= 0,	-- Sports Lottery
	@ShowHB			BIT	= 0,	-- Habanero
	@ShowWM			BIT	= 0,	-- WM Live Casino
	@ShowBGG		BIT	= 0,	-- Big Gaming
	@ShowVGA		BIT	= 0,	-- Vgaming
	@ShowBT			BIT	= 0,	-- Bet Trade
	@ShowCO			BIT	= 0,	-- Cash Out
	@TotalRows		INT		= 0 OUTPUT,
	@SumWinLost		MONEY	= 0 OUTPUT,
	@SumLicenseeWL	MONEY	= 0 OUTPUT,
	@SumComm		MONEY	= 0 OUTPUT,
	@SumPlayerComm	MONEY	= 0 OUTPUT
AS

/*
	Created: Kos@20180604
	Task: Customer List Bet List - Settled
	DB: DBACC.bodb02
	Revisions:
		- 20180604@Kos: Created [#Redmine: 96319]
		- 20180720@Kos: Support Pragmatic Casino [#Redmine: 92318]
		- 20190401@Kos: Don't support Microgaming Live Casino and Microgaming RNG Casino anymore [#Redmine: 107704]
					- Remove params @ShowMGCLC and @ShowMGCRNG
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190523@Kos: Support more base currency [#Redmine: 112531]
		- 20190704@Kos: Support Card Club [Redmine: #115449]
		- 20191209@Kos: Support Spadegaming [Redmine: #124103]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200208@Kos: Support Virtual Games [Redmine: #124911]
		- 20200402@Kos: Support Table Games [Redmine: #131447]
		- 20200416@Kos: Support Indo 4D [Redmine: #130859]
		- 20200425@Kos: Support status Delay Payout [Redmine: #132629]
		- 20200502@Kos: Support Table Game Half Won Half Lose [Redmine: #133323]
		- 20200511@Kos: Support Sexy Gaming [Redmine: #130859]
		- 20200518@Kos: Support Saba.club [Redmine: #132702]
		- 20200525@Kos: Support show licensee transaction ID [Redmine: #134629]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20200714@Kos: Support PP Jackpot [Redmine: #137290]
		- 20200728@Kos: Support SA Gaming [Redmine: #128493]
		- 20200815@Kos: Support PG Soft [Redmine: #139182]
		- 20200922@Kos: Support Joker [Redmine: #141408]
		- 20201210@Kos: Exclude bettype 999 Odds Spread Adjustment [Redmine: #142532]
		- 20201231@Kos: Support Happy 5 Linked Games [Redmine: #147446]
		- 20210112@Kos: Support GDG [Redmine: #147267]
		- 20210118@Kos: Support Saba.club Jackpot Contribution and Jackpot Prize tickets [Redmine: #148100]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210311@Kos: Support Sports Lottery [Redmine: #150872]
		- 20210415@Kos: Support Habanero [Redmine: #150843]
		- 20210506@Kos: Support WM Live Casino [Redmine: #140944]
		- 20210517@Kos: Support Big Gaming [Redmine: #146773]
		- 20210524@Kos: Support Vgaming [Redmine: #151583]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Invalid Parameter.'

		RETURN
	END CATCH

	-- Get SportBetTypeMatrix
	DECLARE @SportBettype TABLE ( ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE (ProductID = 1 AND (@ShowSB = 1 OR @ShowBA = 1))		-- Sportsbook, BA
		OR (ProductID = 3 AND @ShowNG = 1)						-- Number Game
		OR (ProductID = 5 AND @ShowVS = 1)						-- Virtual Sports
		OR (ProductID = 6 AND @ShowCS = 1)						-- RNG Casino
		OR (ProductID = 8 AND @ShowKN = 1)						-- Keno
		OR (ProductID = 11 AND @ShowAGC = 1)					-- AG Casino
		OR (ProductID = 15 AND @ShowCB = 1)						-- Colossus Bets
		OR (ProductID = 21 AND @ShowAB = 1)						-- AllBet
		OR (ProductID = 22 AND @ShowVB = 1)						-- Macau Games
		OR (ProductID = 24 AND @ShowFW = 1)						-- Fishing World
		OR (ProductID = 25 AND @ShowCO = 1)						-- Cash Out
		OR (ProductID = 27 AND @ShowVS2 = 1)					-- Betradar Virtual Sports
		OR (ProductID = 28 AND @ShowLT = 1)						-- Lottery
		OR (ProductID = 32 AND @ShowPP = 1)						-- Pragmatic Casino
		OR (ProductID = 34 AND @ShowCC = 1)						-- Card Club
		OR (ProductID = 36 AND @ShowSG = 1)						-- Spadegaming
		OR (ProductID = 38 AND @ShowVRG = 1)					-- Virtual Games
		OR (ProductID = 39 AND @ShowSAG = 1)					-- SA Gaming
		OR (ProductID = 40 AND @ShowTG = 1)						-- Table Games
		OR (ProductID = 42 AND @ShowSBC = 1)					-- Saba.club
		OR (ProductID = 43 AND @ShowI4D = 1)					-- Indo 4D
		OR (ProductID = 45 AND @ShowSXG = 1)					-- Sexy Gaming
		OR (ProductID = 51 AND @ShowWM = 1)						-- WM Live Casino
		OR (ProductID = 55 AND @ShowPGS = 1)					-- PG Soft
		OR (ProductID = 56 AND @ShowJK = 1)						-- Joker
		OR (ProductID = 57 AND @ShowBGG = 1)					-- Big Gaming
		OR (ProductID = 59 AND @ShowGDG = 1)					-- GDG
		OR (ProductID = 61 AND @ShowHB = 1)						-- Habanero
		OR (ProductID = 63 AND @ShowSLT = 1)					-- Sports Lottery
		OR (ProductID = 66 AND @ShowVGA = 1)					-- Vgaming
		OR (BetType IN (901, 902, 903) AND @ShowBT = 1)			-- BetTrade

	DELETE @SportBettype
	WHERE BetType IN (904, 914, 801, 802, 803, 804, 805, 806, 999)

	IF @ShowBT = 0
	BEGIN
		DELETE @SportBettype
		WHERE ProductID = 1 AND BetType IN (901, 902, 903)
	END

	CREATE TABLE #Data (
		SportType			INT,
		TransId				BIGINT,
		BetId				BIGINT,
		BetType				SMALLINT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		MOdds				MONEY,
		OddsType			TINYINT,
		Odds				MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		BetTeam				NVARCHAR(10),
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		RefNo				BIGINT,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					NVARCHAR(15),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(20),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		VirtualRate			FLOAT,
		IsShowOTExRate		BIT,
		Currency			TINYINT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		OddsSpread			MONEY
	)

	DECLARE @Today		SMALLDATETIME,
		@Yesterday		SMALLDATETIME,
		@TempToDate		SMALLDATETIME,
		@TempFromDate	SMALLDATETIME

	SELECT @Today = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0),
		@Yesterday = DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)

	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		-- Sportsbook, BA
		IF @ShowSB = 1 OR @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				ISNULL(b.WalletType, 0) AS WalletType,
				ISNULL(b.RefCode, 0) AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.custid = @CustId
				AND b.bettype NOT IN (901, 902, 903)
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND ((b.tpositiontaking <> 0 AND @ShowSB = 1)
					OR (b.tpositiontaking = 0 AND @ShowBA = 1))
				AND sbt.ProductID = 1
				AND sbt.EventType = 1

			-- Outright
			INSERT INTO #Data
			SELECT
				l.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				b.modds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				'' AS BetTeam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.orid AS MatchId,
				m.matchcode,
				m.groupmatch AS Race,
				b.WinLostDate AS EventDate,
				m.teamid AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND ((b.tpositiontaking <> 0 AND @ShowSB = 1)
					OR (b.tpositiontaking = 0 AND @ShowBA = 1))
				AND b.bettype = 10

			-- Mix Parlay, System Parlay
			INSERT INTO #Data
			SELECT
				0 AS SportType,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.betid, 0) = 0 THEN b.transid
							ELSE b.betid
						END
				END AS transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.custid = @CustId
				AND b.matchid IN (9, 29)
				AND b.bettype IN (9, 29)
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND ((b.tpositiontaking <> 0 AND @ShowSB = 1)
					OR (b.tpositiontaking = 0 AND @ShowBA = 1))
		END

		-- Mix Parlay (Betradar Virtual Sports)
		IF @ShowVS2 = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				0 AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.custid = @CustId
				AND b.matchid = 2799
				AND b.bettype = 2799
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
		END

		-- BetTrade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(ob.bettype, 0) AS BetId,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				ob.odds,
				ob.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				CASE
					WHEN b.bettype = 903 THEN b.awinlost
					ELSE b.comm
				END AS Comm,
				b.playercomm,
				b.liveindicator,
				ob.livehomescore,
				ob.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.refno = ob.transid
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.custid = @CustId
				AND b.bettype IN (901, 902, 903)
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
		END

		-- Cash Out
		IF @ShowCO = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.bettype, 0) AS BetId,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				CASE
					WHEN b.bettype = 913 THEN b.awinlost
					ELSE b.comm
				END AS Comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.custid = @CustId
				AND sbt.ProductID = 25
				AND b.statusID IN (111, 112, 113, 101, 102, 103)

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 911)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM #Data AS b
					INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911
			END

			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 912)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid,
					b.Stake = cob.stake,
					b.Comm = ISNULL(cb.Comm, 0)
				FROM #Data AS b
					INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN #Data AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
				WHERE b.BetType = 912
			END
		END

		-- Number Game, Virtual Sports, Betradar Virtual Sports (EventType = 1)
		IF @ShowNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CASE 
					WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE ''
				END AS ShowTime,
				'' AS BetCheck,
				CASE
					WHEN sbt.ProductID = 27 THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND sbt.ProductID IN (3, 5, 27)
				AND sbt.EventType = 1
		END

		-- Virtual Sports (EventType = 3)
		IF @ShowVS = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				r.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				r.LeagueID,
				o.EventID AS MatchId,
				CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
				b.oddsid AS Race,
				b.WinLostDate AS EventDate,
				o.RacerID AS HomeId,
				0 AS AwayId,
				r.BetStatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CONVERT(VARCHAR(20), r.EventTime) AS ShowTime,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
		END

		-- Keno, Lottery, Virtual Games, Table Games, Indo 4D, Happy 5 Linked Games, Sports Lottery
		IF @ShowKN = 1 OR @ShowLT = 1 OR @ShowVRG = 1 OR @ShowTG = 1 OR @ShowI4D = 1 OR @ShowNG = 1 OR @ShowSLT = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				CASE
					WHEN sbt.ProductID = 8 THEN 202
					WHEN sbt.ProductID = 28 THEN 220
					WHEN sbt.ProductID IN (3, 38, 40, 43, 63) THEN b.matchid
					ELSE 0
				END AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS Modds,
				ISNULL(b.oddstype, 0),
				b.odds,
				b.stake,
				b.actual_stake,
				ISNULL(b.betteam, ''),
				CASE
					WHEN sbt.ProductID = 40 AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
					WHEN sbt.ProductID = 40 AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
					ELSE b.status
				END AS status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductId = 8 THEN ISNULL(b.comstatus, '')
					WHEN sbt.ProductID IN (3, 38, 63) THEN ISNULL(b.betcheck, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN sbt.ProductID IN (3, 8, 28, 38, 40, 43, 63) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate 
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND (sbt.ProductID IN (8, 28, 38, 40, 43, 63)
					OR (sbt.ProductID = 3 AND sbt.EventType = 0))
		END

		-- RNG Casino Single Wallet, Voidbridge, Fishing World, Pragmatic Casino, Card Club, Spadegaming, Saba.club, PG Soft, Habanero, Vgaming
		IF (@ShowCS = 1 OR @ShowVB = 1 OR @ShowFW = 1 OR @ShowPP = 1 OR @ShowCC = 1 OR @ShowSG = 1 OR @ShowSBC = 1 OR @ShowPGS = 1 OR @ShowJK = 1 OR @ShowHB = 1 OR @ShowVGA = 1)
			AND EXISTS (SELECT 1 FROM dbo.bettrans AS b WITH (NOLOCK)
							INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
						WHERE b.custid = @CustId
							AND (sbt.ProductID IN (22, 24, 32, 34, 36, 42, 55, 56, 61, 66)
								OR (sbt.ProductID = 6 AND sbt.SubProduct <> '')))
		BEGIN
			-- Up to yesterday settled ticket
			INSERT INTO #Data
			SELECT
				CASE
					WHEN sbt.ProductID IN (6, 34, 36, 42, 55, 56, 61, 66) THEN b.matchid
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 24 THEN 219
					WHEN sbt.ProductID = 32 THEN 248
					ELSE 0
				END AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				CASE
					WHEN sbt.ProductID IN (32, 42, 66) THEN b.odds
					ELSE 0
				END AS Odds,
				b.stake,
				b.actual_stake,
				'' AS BetTeam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS BetCheck,
				b.transdesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				CASE
					WHEN sbt.ProductID IN (32, 42, 66) THEN ISNULL(b.oddsspread, 0)
					ELSE 0
				END AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.winlostdate < @Yesterday	-- not yesterday and today
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113)
				AND (sbt.ProductID IN (22, 24, 32, 34, 36, 42, 55, 56, 61, 66)
					OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))

			IF @ToDate >= @Yesterday AND @TempFromDate <= @Today
			BEGIN
				-- Yesterday and today settled ticket
				INSERT INTO #Data
				SELECT
					CASE
						WHEN sbt.ProductID IN (6, 34, 36, 42, 55, 56, 61, 66) THEN b.matchid
						WHEN sbt.ProductID = 22 THEN 212
						WHEN sbt.ProductID = 24 THEN 219
						WHEN sbt.ProductID = 32 THEN 248
						ELSE 0
					END AS SportType,
					b.transid,
					ISNULL(b.betid, 0),
					b.bettype,
					0 AS Hdp1,
					0 AS Hdp2,
					0 AS MOdds,
					0 AS OddsType,
					CASE
						WHEN sbt.ProductID IN (32, 42, 66)
							THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
						ELSE 0
					END AS Odds,
					SUM(brng.stake) AS Stake,
					SUM(brng.actual_stake) AS Actual_Stake,
					'' AS BetTeam,
					CASE 
						WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
						WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					b.refno,
					b.transdate,
					b.winlostdate,
					SUM(brng.winlost - brng.actual_stake) AS WinLost,
					SUM(- (brng.winlost - brng.actual_stake)) AS LicenseeWL,
					SUM(brng.comm) AS Comm,
					SUM(brng.playercomm) AS PlayerComm,
					0 AS LiveIndicator,
					0 AS LiveHomeScore,
					0 AS LiveAwayScore,
					b.ip,
					0 AS LeagueId,
					0 AS MatchId,
					'' AS MatchCode,
					'' AS Race,
					b.WinLostDate AS EventDate,
					0 AS HomeId,
					0 AS AwayId,
					'' AS BetStatus,
					CONVERT(BIT, 0) AS IsNeutral,
					0,
					0,
					b.currency,
					'' AS ShowTime,
					'' AS BetCheck,
					b.transdesc,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS OriginalStake,
					0 AS OriginalBetType,
					0 AS WalletType,
					0 AS RefCode,
					CASE
						WHEN sbt.ProductID IN (32, 42, 66) THEN ISNULL(SUM(brng.BetStake), 0)
						ELSE 0
					END AS OddsSpread
				FROM
					dbo.bettransRnG AS brng WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND b.winlostdate BETWEEN @Yesterday AND @Today
					AND b.custid = @CustId
					AND brng.statusID NOT IN (0, 1)
					AND (sbt.ProductID IN (22, 24, 32, 34, 36, 42, 55, 56, 61, 66)
						OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
				GROUP BY
					b.transid,
					ISNULL(b.betid, 0),
					b.bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.ip,
					b.currency,
					b.matchid,
					b.transdesc,
					sbt.ProductID
			END
		END

		-- AG Casino, AllBet, SA Gaming, Sexy Gaming, GDG, WM Live Casino, Big Gaming
		IF (@ShowAGC = 1 OR @ShowAB = 1 OR @ShowSAG = 1 OR @ShowSXG = 1 OR @ShowGDG = 1 OR @ShowWM = 1 OR @ShowBGG = 1)
			AND EXISTS (SELECT 1 FROM dbo.bettrans AS b WITH (NOLOCK)
							INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
						WHERE b.custid = @CustId AND sbt.ProductID IN (11, 21, 39, 45, 51, 57, 59))
		BEGIN
			-- Up to yesterday settled ticket
			INSERT INTO #Data
			SELECT
				CASE
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 21 THEN 211
					ELSE b.matchid
				END AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				0 AS Odds,
				b.stake,
				b.actual_stake,
				'' AS BetTeam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.winlostdate < @Yesterday	-- not yesterday and today
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113)
				AND sbt.ProductID IN (11, 21, 39, 45, 51, 57, 59)

			IF @ToDate >= @Yesterday AND @TempFromDate <= @Today
			BEGIN
				-- Yesterday and today settled ticket
				INSERT INTO #Data
				SELECT
					CASE
						WHEN sbt.ProductID = 11 THEN 250
						WHEN sbt.ProductID = 21 THEN 211
						ELSE b.matchid
					END AS SportType,
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					0 AS Hdp1,
					0 AS Hdp2,
					0 AS MOdds,
					0 AS OddsType,
					0 AS Odds,
					SUM(blc.stake) AS Stake,
					SUM(blc.actual_stake) AS Actual_Stake,
					'' AS BetTeam,
					CASE 
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					b.refno,
					b.transdate,
					b.winlostdate,
					SUM(blc.winlost - blc.actual_stake) AS WinLost,
					SUM(- (blc.winlost - blc.actual_stake)) AS LicenseeWL,
					SUM(blc.comm) AS Comm,
					SUM(blc.playercomm) AS PlayerComm,
					0 AS LiveIndicator,
					0 AS LiveHomeScore,
					0 AS LiveAwayScore,
					b.ip,
					0 AS LeagueId,
					0 AS MatchId,
					'' AS MatchCode,
					'' AS Race,
					b.WinLostDate AS EventDate,
					0 AS HomeId,
					0 AS AwayId,
					'' AS BetStatus,
					CONVERT(BIT, 0) AS IsNeutral,
					0,
					0,
					b.currency,
					'' AS ShowTime,
					'' AS BetCheck,
					'' AS TransDesc,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS OriginalStake,
					0 AS OriginalBetType,
					0 AS WalletType,
					0 AS RefCode,
					0 AS OddsSpread
				FROM
					dbo.bettransLC AS blc WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @ToDate
					AND b.winlostdate BETWEEN @Yesterday AND @Today
					AND b.custid = @CustId
					AND blc.statusID NOT IN (0, 1)
					AND sbt.ProductID IN (11, 21, 39, 45, 51, 57, 59)
				GROUP BY
					b.transid,
					ISNULL(b.betid, 0),
					b.bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.ip,
					b.currency,
					sbt.ProductID,
					b.matchid
			END
		END

		-- Colossus Bets
		IF @ShowCB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				204 AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				0 AS Odds,
				b.stake,
				b.actual_stake,
				'' AS BetTeam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND sbt.ProductID = 15
		END
	END

	IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @BalanceUpDay < @FromDate
			SELECT @BalanceUpDay = @FromDate

		-- Sportsbook, BA
		IF @ShowSB = 1 OR @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2, 
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake),
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				ISNULL(b.WalletType, 0) AS WalletType,
				ISNULL(b.RefCode, 0) AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId 
				AND b.bettype NOT IN (901, 902, 903)
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND ((b.tpositiontaking <> 0 AND @ShowSB = 1)
					OR (b.tpositiontaking = 0 AND @ShowBA = 1))
				AND sbt.ProductID = 1
				AND sbt.EventType = 1

			-- Outright
			INSERT INTO #Data
			SELECT
				l.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				b.modds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				'' AS BetTeam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.orid AS MatchId,
				m.matchcode,
				m.groupmatch AS Race,
				b.WinLostDate AS EventDate,
				m.teamid AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND ((b.tpositiontaking <> 0 AND @ShowSB = 1)
					OR (b.tpositiontaking = 0 AND @ShowBA = 1))
				AND b.bettype = 10

			-- Mix Parlay, System Parlay
			INSERT INTO #Data
			SELECT
				0 AS SportType,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.betid, 0) = 0 THEN b.transid
							ELSE b.betid
						END
				END AS TransId,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND b.matchid IN (9, 29)
				AND b.bettype IN (9, 29)
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND ((b.tpositiontaking <> 0 AND @ShowSB = 1)
					OR (b.tpositiontaking = 0 AND @ShowBA = 1))
		END

		-- Mix Parlay (Betradar Virtual Sports)
		IF @ShowVS2 = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				0 AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND b.matchid = 2799
				AND b.bettype = 2799
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
		END
	
		-- Bet trade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(ob.bettype, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				ob.odds,
				ob.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				CASE
					WHEN b.bettype = 903 THEN b.awinlost
					ELSE b.comm
				END AS Comm,
				b.playercomm,
				b.liveindicator,
				ob.livehomescore,
				ob.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.bettrans14 AS ob WITH(NOLOCK) ON b.refno = ob.transid
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND b.bettype IN (901, 902, 903)
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
		END

		-- Cash Out
		IF @ShowCO = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.bettype, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				CASE
					WHEN b.bettype = 913 THEN b.awinlost
					ELSE b.comm
				END AS Comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND sbt.ProductID = 25

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 911)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM #Data AS b
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911
			END

			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 912)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid,
					b.Stake = cob.stake,
					b.Comm = ISNULL(cb.Comm, 0)
				FROM #Data AS b
					INNER JOIN dbo.bettrans14 AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN #Data AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
				WHERE b.BetType = 912
			END
		END

		-- Number Game, Virtual Sports, Betradar Virtual Sports (EventType = 1)
		IF @ShowNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CASE
					WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE '' 
				END AS ShowTime,
				'' AS BetCheck,
				CASE
					WHEN sbt.ProductID = 27 THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND sbt.ProductID IN (3, 5, 27)
				AND sbt.EventType = 1
		END

		-- Virtual Sports
		IF @ShowVS = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				r.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				r.LeagueID,
				o.EventID AS MatchId,
				CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
				b.oddsid AS Race,
				b.WinLostDate AS EventDate,
				o.RacerID AS HomeId,
				0 AS AwayId,
				r.BetStatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CONVERT(VARCHAR(20), r.EventTime) AS ShowTime,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
		END

		-- RNG Casino, Keno, AG Casino, AllBet, Voidbridge, Fishing World, Lottery, Pragmatic Casino, Card Club, Spadegaming, Virtual Games
		-- SA Gaming, Table Games, Indo 4D, Sexy Gaming, Saba.club, PG Soft, Joker, Happy 5 Linked Games, GDG, Sports Lottery, Habanero, WM Live Casino, Vgaming
		-- Big Gaming
		IF @ShowCS = 1 OR @ShowKN = 1 OR @ShowAGC = 1 OR @ShowAB = 1 OR @ShowVB = 1 OR @ShowFW = 1 OR @ShowLT = 1 OR @ShowPP = 1
			OR @ShowCC = 1 OR @ShowSG = 1 OR @ShowVRG = 1 OR @ShowSAG = 1 OR @ShowTG = 1 OR @ShowI4D = 1 OR @ShowSXG = 1 OR @ShowSBC = 1 OR @ShowPGS = 1
			OR @ShowJK = 1 OR @ShowNG = 1 OR @ShowGDG = 1 OR @ShowSLT = 1 OR @ShowHB = 1 OR @ShowWM = 1 OR @ShowBGG = 1 OR @ShowVGA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.matchid
					WHEN sbt.ProductID = 8 THEN 202
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 21 THEN 211
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 24 THEN 219
					WHEN sbt.ProductID = 28 THEN 220
					WHEN sbt.ProductID = 32 THEN 248
					WHEN sbt.ProductID IN (3, 34, 36, 38, 39, 40, 42, 43, 45, 51, 55, 56, 57, 59, 61, 63, 66) THEN b.matchid
					ELSE 0
				END AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS Oddstype,
				CASE
					WHEN sbt.ProductID IN (8, 28, 32, 38, 40, 42, 43, 63, 66) THEN b.odds
					ELSE 0
				END AS Odds,
				b.stake,
				b.actual_stake,
				'' AS BetTeam,
				CASE
					WHEN sbt.ProductID = 40 AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
					WHEN sbt.ProductID = 40 AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
					ELSE b.status
				END AS status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductId = 8 THEN ISNULL(b.comstatus, '')
					WHEN sbt.ProductId IN (3, 38, 63) THEN ISNULL(b.betcheck, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.transdesc
					WHEN sbt.ProductID IN (3, 8, 22, 24, 28, 32, 34, 36, 38, 40, 43, 55, 56, 61, 63) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				CASE
					WHEN sbt.ProductID IN (32, 42, 66) THEN ISNULL(b.oddsspread, 0)
					ELSE 0
				END AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND (sbt.ProductID IN (6, 8, 11, 21, 22, 24, 28, 32, 34, 36, 38, 39, 40, 42, 43, 45, 51, 55, 56, 57, 59, 61, 63, 66)
					OR (sbt.ProductID = 3 AND sbt.EventType = 0))
		END

		-- Colossus Bets
		IF @ShowCB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				204 AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				0 AS Odds,
				b.stake,
				b.actual_stake,
				'' AS BetTeam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
				LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND sbt.ProductID = 15
		END
	END

	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @ToDate

		-- Sportsbook, BA
		IF @ShowSB = 1 OR @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				ISNULL(b.WalletType, 0) WalletType,
				ISNULL(b.RefCode, 0) AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN bodb_Archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND b.bettype NOT IN (901, 902, 903)
				AND ((b.tpositiontaking <> 0 AND @ShowSB = 1)
					OR (b.tpositiontaking = 0 AND @ShowBA = 1))
				AND sbt.ProductID = 1
				AND sbt.EventType = 1

			-- Outright
			INSERT INTO #Data
			SELECT
				l.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				b.modds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				'' AS BetTeam,
				b.Status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.ip,
				m.leagueid,
				m.orid AS MatchId,
				m.matchcode,
				m.groupmatch AS Race,
				b.WinLostDate AS EventDate,
				m.teamid AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN bodb_Archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND ((b.tpositiontaking <> 0 AND @ShowSB = 1)
					OR (b.tpositiontaking = 0 AND @ShowBA = 1))
				AND b.bettype = 10

			-- Mix Parlay, System Parlay
			INSERT INTO #Data
			SELECT
				0 AS SportType,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.betid, 0) = 0 THEN b.transid
							ELSE b.betid
						END
				END AS transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN b.tpositiontaking = 0 THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			WHERE
				b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND b.matchid IN (0, 9, 29) --should NOT remove 0 IN archive
				AND b.bettype IN (9, 29)
				AND ((b.tpositiontaking <> 0 AND @ShowSB = 1)
					OR (b.tpositiontaking = 0 AND @ShowBA = 1))
		END

		-- Mix Parlay (Betradar Virtual Sports)
		IF @ShowVS2 = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				0 AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				0 AS OddsType,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			WHERE
				b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND b.matchid = 2799
				AND b.bettype = 2799
		END
	
		-- Bet trade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(ob.bettype, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				ob.odds,
				ob.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				CASE
					WHEN b.bettype = 903 THEN b.awinlost
					ELSE b.comm
				END AS Comm,
				b.playercomm,
				b.liveindicator,
				ob.livehomescore,
				ob.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.refno = ob.transid
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND b.bettype IN (901, 902, 903)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
		END

		-- Cash Out
		IF @ShowCO = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.bettype, 0) AS BetId,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				CASE
					WHEN b.bettype = 913 THEN b.awinlost
					ELSE b.comm
				END AS Comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND sbt.ProductID = 25

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 911)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM #Data AS b
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911
			END

			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 912)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid,
					b.Stake = cob.stake,
					b.Comm = ISNULL(cb.Comm, 0)
				FROM #Data AS b
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN #Data AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
				WHERE b.BetType = 912
			END
		END

		-- Number Game, Virtual Sports, Betradar Virtual Sports (EventType = 1)
		IF @ShowNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CASE 
					WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE '' 
				END AS ShowTime,
				'' AS BetCheck,
				CASE
					WHEN sbt.ProductID = 27 THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid 
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND sbt.ProductID IN (3, 5, 27)
				AND sbt.EventType = 1
		END

		-- Virtual Sports (EventType = 3)
		IF @ShowVS = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				r.sporttype,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				r.LeagueID,
				o.EventID AS MatchId,
				CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
				b.oddsid AS Race,
				b.WinLostDate AS EventDate,
				o.RacerID AS HomeId,
				0 AS AwayId,
				r.BetStatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CONVERT(VARCHAR(20), r.EventTime) AS ShowTime,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN bodb_Archive.dbo.VSRaceInfo_bk AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
		END

		-- RNG Casino, Keno, AG Casino, AllBet, Voidbridge, Fishing World, Lottery, Pragmatic Casino, Card Club, Spadegaming, Virtual Games
		-- SA Gaming, Table Games, Indo 4D, Sexy Gaming, Saba.club, PG Soft, Joker, Happy 5 Linked Games, GDG, Sports Lottery, Habanero, WM Live Casino, Vgaming
		-- Big Gaming
		IF @ShowCS = 1 OR @ShowKN = 1 OR @ShowAGC = 1 OR @ShowAB = 1 OR @ShowVB = 1 OR @ShowFW = 1 OR @ShowLT = 1 OR @ShowPP = 1
			OR @ShowCC = 1 OR @ShowSG = 1 OR @ShowVRG = 1 OR @ShowSAG = 1 OR @ShowTG = 1 OR @ShowI4D = 1 OR @ShowSXG = 1 OR @ShowSBC = 1 OR @ShowPGS = 1
			OR @ShowJK = 1 OR @ShowNG = 1 OR @ShowGDG = 1 OR @ShowSLT = 1 OR @ShowHB = 1 OR @ShowWM = 1 OR @ShowBGG = 1 OR @ShowVGA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN 251
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.matchid
					WHEN sbt.ProductID = 8 THEN 202
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 21 THEN 211
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 24 THEN 219
					WHEN sbt.ProductID = 28 THEN 220
					WHEN sbt.ProductID = 32 THEN 248
					WHEN sbt.ProductID IN (3, 34, 36, 38, 39, 40, 42, 43, 45, 55, 56, 57, 59, 61, 63, 66) THEN b.matchid
					ELSE 0
				END AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp1
					ELSE 0
				END AS Hdp1,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp2
					ELSE 0
				END AS Hdp2,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.modds
					ELSE 0
				END AS MOdds,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.oddstype
					ELSE 0
				END AS Oddstype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Odds
					WHEN sbt.ProductID IN (8, 28, 32, 38, 40, 42, 43, 63, 66) THEN b.odds
					ELSE 0
				END AS Odds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN ISNULL(b.betteam, '')
					ELSE ''
				END AS BetTeam,
				CASE
					WHEN sbt.ProductID = 40 AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
					WHEN sbt.ProductID = 40 AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
					ELSE b.status
				END AS status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				0 AS LeagueId,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.bettype
					ELSE 0
				END AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductId = 8 THEN ISNULL(b.comstatus, '')
					WHEN sbt.ProductId IN (3, 38, 63) THEN ISNULL(b.betcheck, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.transdesc
					WHEN sbt.ProductID IN (3, 8, 22, 24, 28, 32, 34, 36, 38, 40, 43, 55, 56, 61, 63) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				CASE
					WHEN sbt.ProductID IN (32, 42, 66) THEN ISNULL(b.oddsspread, 0)
					ELSE 0
				END AS OddsSpread
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustId
				AND (sbt.ProductID IN (6, 8, 11, 21, 22, 24, 28, 32, 34, 36, 38, 39, 40, 42, 43, 45, 51, 55, 56, 57, 59, 61, 63, 66)
					OR (sbt.ProductID = 3 AND sbt.EventType = 0))
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
		END

		-- Colossus Bets
		IF @ShowCB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				204 AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				0 AS Odds,
				b.stake,
				b.actual_stake,
				'' AS BetTeam,
				b.status,
				0 AS SettlementStatus,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				b.WinLostDate AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
				LEFT JOIN bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113, 101, 102, 103)
				AND sbt.ProductID = 15
		END
	END

	IF @ShowBT = 1
	BEGIN
		UPDATE b
		SET b.comm = cb.comm
		FROM #Data AS b
			INNER JOIN #Data AS cb ON b.RefNo = cb.RefNo
		WHERE b.SportType = 1
			AND b.BetType = 902
			AND cb.BetType = 903

		DELETE #Data WHERE Sporttype = 1 AND Bettype = 903
	END

	IF @ShowCO = 1
	BEGIN
		DELETE #Data WHERE Bettype = 913
	END

	DELETE #Data
	WHERE Currency NOT IN (SELECT DISTINCT Currency FROM @TempAg)

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode			BIGINT,
			TransId			BIGINT,
			Stake			MONEY,
			Actual_Stake	MONEY,
			WinLost			MONEY,
			LicenseeWL		MONEY,
			Comm			MONEY,
			PlayerComm		MONEY
		)

		-- Prepare temp table
		INSERT INTO @RefCodeTmp
		SELECT
			RefCode,
			MIN(TransId) AS TransId,
			SUM(Stake) AS Stake,
			SUM(Actual_Stake) AS Actual_Stake,
			SUM(WinLost) AS WinLost,
			SUM(LicenseeWL) AS LicenseeWL,
			SUM(Comm) AS Comm,
			SUM(PlayerComm) AS PlayerComm
		FROM #Data
		WHERE RefCode <> 0
		GROUP BY RefCode
		HAVING COUNT(*) > 1

		IF EXISTS (SELECT 1 FROM @RefCodeTmp)
		BEGIN
			-- Update data for summmary ticket
			UPDATE b
			SET
				b.Stake = r.Stake,
				b.Actual_Stake = r.Actual_Stake,
				b.WinLost = r.WinLost,
				b.LicenseeWL = r.LicenseeWL,
				b.Comm = r.Comm,
				b.PlayerComm = r.PlayerComm,
				b.WalletType = 0
			FROM #Data AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE #Data
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE #Data
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE #Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM #Data

	-- Get exchange rate
	CREATE TABLE #ExchangeRate (
		ExchangeDate	SMALLDATETIME,
		ExchangeId		INT,
		Rate			FLOAT
	)

	IF @BaseCurrency <> ''
	BEGIN
		INSERT INTO #ExchangeRate
		SELECT
			e.exchangedate,
			e.ExchangeId,
			CASE
				WHEN @BaseCurrency = 'MYR' THEN e.MYR
				WHEN @BaseCurrency = 'USD' THEN e.USD
				WHEN @BaseCurrency = 'EUR' THEN e.EUR
				WHEN @BaseCurrency = 'CNY' THEN e.CNY
				WHEN @BaseCurrency = 'IDR' THEN e.IDR
				WHEN @BaseCurrency = 'GBP' THEN e.GBP
				WHEN @BaseCurrency = 'THB' THEN e.THB
				WHEN @BaseCurrency = 'INH' THEN e.INH
				WHEN @BaseCurrency = 'BDT' THEN e.BDT
				WHEN @BaseCurrency = 'INR' THEN e.INR
				ELSE 1
			END AS Rate
		FROM Lrf_f_GetExchangeDaily(@ExFromDate, @ExToDate) AS e
		WHERE EXISTS (SELECT 1 FROM #Data WHERE Currency = e.ExchangeId AND WinLostDate = e.exchangedate)
	END

	-- Return data
	SELECT
		@TotalRows		= COUNT(b.TransId),
		@SumWinlost		= SUM(b.WinLost		* ISNULL(e.Rate, 1)),
		@SumLicenseeWL	= SUM(b.LicenseeWL	* ISNULL(e.Rate, 1)),
		@SumComm		= SUM(b.Comm		* ISNULL(e.Rate, 1)),
		@SumPlayerComm	= SUM(b.PlayerComm	* ISNULL(e.Rate, 1))
	FROM #Data AS b
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeDate = b.WinLostDate AND e.ExchangeId = b.Currency

	-- Get sort text
	IF @BaseCurrency <> ''
		AND (@Sort LIKE '%Stake%' OR @Sort LIKE '%WinLost%' OR @Sort LIKE '%LicenseeWL%')
	BEGIN
		DECLARE @CharIndex TINYINT

		SELECT @CharIndex = CHARINDEX(' ', @Sort, 1)

		SELECT @Sort = SUBSTRING(@Sort, 0, @CharIndex) + ' * ISNULL(e.Rate, 1)' + SUBSTRING(@Sort, @CharIndex, LEN(@Sort))
	END

	DECLARE @PagingData AS TABLE (
		RowNum				INT,
		SportType			INT,
		TransId				BIGINT,
		BetId				BIGINT,
		BetType				SMALLINT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		MOdds				MONEY,
		OddsType			TINYINT,
		Odds				MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		BetTeam				NVARCHAR(10),
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		RefNo				BIGINT,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					NVARCHAR(15),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(20),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		VirtualRate			FLOAT,
		IsShowOTExRate		BIT,
		Currency			TINYINT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		OddsSpread			MONEY
	)

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Sql NVARCHAR(2000)

	SET @Sql = 
		'SELECT a.*
		FROM
			(
				SELECT
					ROW_NUMBER() OVER (ORDER BY ' + @Sort +') AS RowNum,
					d.*
				FROM #Data AS d' +
				CASE
					WHEN @Sort LIKE '%e.Rate%' THEN '
					LEFT JOIN #ExchangeRate AS e
						ON e.ExchangeDate = d.WinLostDate AND e.ExchangeId = d.Currency'
					ELSE ' '
				END + '
			) AS a
		WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
		ORDER BY a.RowNum'

	INSERT INTO @PagingData
	EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

	SELECT
		@CustId AS CustId,
		a.SportType,
		a.TransId,
		a.BetId,
		a.BetType,
		a.Hdp1,
		a.Hdp2,
		a.MOdds,
		a.OddsType,
		a.Odds,
		a.Stake * ISNULL(e.Rate, 1) AS Stake,
		a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
		a.BetTeam,
		a.Status,
		a.SettlementStatus,
		a.RefNo,
		a.TransDate,
		a.WinLostDate,
		a.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		a.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
		a.Comm * ISNULL(e.Rate, 1) AS Comm,
		a.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		a.LiveIndicator,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.Ip,
		a.LeagueId,
		a.MatchId,
		a.MatchCode,
		a.Race,
		a.EventDate,
		a.HomeId,
		a.AwayId,
		a.BetStatus,
		a.IsNeutral,
		a.VirtualRate,
		a.IsShowOTExRate,
		a.Currency,
		a.ShowTime,
		a.BetCheck,
		a.TransDesc,
		a.BetdaqId,
		a.ExtraInfo,
		a.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode,
		a.OddsSpread
	FROM @PagingData AS a
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeDate = a.WinLostDate AND e.ExchangeId = a.Currency
	ORDER BY a.RowNum ASC

	-- Get sub tickets
	DECLARE @Detail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10)
	)

	-- Virtual Sports
	IF EXISTS (	SELECT 1
				FROM @PagingData AS b
					INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				WHERE sbt.ProductId = 5 AND sbt.EventType = 3)
	BEGIN
		IF @ToDate > @MoveBetsDay
		BEGIN
			INSERT INTO @Detail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake * ISNULL(e.Rate, 1) AS Stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.betteam
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @PagingData AS b ON bm.refno = b.RefNo
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
				LEFT JOIN #ExchangeRate AS e
					ON e.ExchangeDate = b.WinLostDate AND e.ExchangeId = b.Currency
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND sbtm.ProductID = 5
				AND sbtm.EventType = 3
		END

		IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
		BEGIN
			INSERT INTO @Detail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake * ISNULL(e.Rate, 1) AS Stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.betteam
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN @PagingData AS b ON bm.refno = b.RefNo
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
				LEFT JOIN #ExchangeRate AS e
					ON e.ExchangeDate = b.WinLostDate AND e.ExchangeId = b.Currency
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND sbtm.ProductID = 5
				AND sbtm.EventType = 3
		END

		IF @FromDate < @BalanceUpDay
		BEGIN
			INSERT INTO @Detail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake * ISNULL(e.Rate, 1) AS Stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.betteam
			FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @PagingData AS b ON bm.refno = b.RefNo
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
				LEFT JOIN #ExchangeRate AS e
					ON e.ExchangeDate = b.WinLostDate AND e.ExchangeId = b.Currency
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND sbtm.ProductID = 5
				AND sbtm.EventType = 3
		END
	END 

	SELECT DISTINCT * FROM @Detail

	DROP TABLE #Data
	DROP TABLE #ExchangeRate
END
GO
