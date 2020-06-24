/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_PlatformWinLoss_Mem]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,

	@ShowSB		BIT = 0,	-- Sportsbook
	@ShowNG		BIT = 0,	-- Number Game
	@ShowVS		BIT = 0,	-- Virtual Sports
	@ShowCS		BIT = 0,	-- RNG Casino
	@ShowKN		BIT = 0,	-- Keno
	@ShowVB		BIT = 0,	-- Macau Games
	@ShowFW		BIT = 0,	-- Fishing World
	@ShowVS2	BIT = 0,	-- Betradar Virtual Sports
	@ShowLT		BIT = 0,	-- Lottery
	@ShowTG		BIT = 0,	-- Table Games
	@ShowI4D	BIT = 0,	-- Indo 4D
	@ShowBA		BIT = 0,

	@BaseCurrency	VARCHAR(10),
	@PageIndex		INT = 1,
	@PageSize		INT = 1000,
	@TotalRows		INT = 0 OUTPUT,

	@SumWinlost		MONEY = 0 OUTPUT,
	@SumLicenseeWL	MONEY = 0 OUTPUT,
	@SumComm		MONEY = 0 OUTPUT,
	@SumPlayerComm	MONEY = 0 OUTPUT,

	@DrawFilter		TINYINT	= 1,
	@PlatformType	TINYINT	= 1
AS

/*
	Created: 20160330@Kos
	Task: Betlist for Platform Win Loss Report
	Original: Lrf_BetList_MobileReport_SelWinloss_Mem
	DB: DBACC.bodb02
	Revisions:
		- 20130618@Jim: Restrict permission of Licensee Users by currency
		- 20130904@Jim: Support Virtual Horse Racing
		- 20140630@Hannah: Offer BetRadar and Sporting Solution
		- 20140908@Jim: Restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141128@Jim: Add more input param @CurrencyID
		- 20150414@Winnie: Apply sporttype bettype matrix & 60 bettype betradar
		- 20150608@Edward: Exclude 3 transactions SOLD/BOUGHT/BetTrade Commission of BetTrade
		- 20150609@Edward: Support Microgaming
		- 20150729@Edward: Return betcheck for Microgaming
		- 20150916@Kos: Don't support Microgaming RNG ticket
		- 20150922@Kos: Don't support Microgaming
		- 20151028@Kos: Change product ID of Microgaming RNG Casino to 17
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151225@Kos: Don't support RNG Casino
		- 20160202@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160224@Kos: Don't support Racing, Live Casino and Platform Amendment [Redmine: #50939]
		- 20160330@Kos: Support Platform New Amendment [Redmine: #54751]
		- 20160427@Kos: Support Voidbridge [Redmine: #54925]
		- 20160427@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160714@Kos: Change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20161004@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20161111@Kos: Support Fishing World [#Redmine: 66737]
		- 20170303@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170306@Kos: Support sub licensees [#Redmine: 71679]
		- 20170327@Kos: Support CashOut [#Redmine: 71963]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170628@Kos: Hotfix - CashOut Details link in Racing tickets [#Redmine: 79076]
		- 20170724@Kos: Support Keno Lottery [#Redmine: 79997]
		- 20170803@Kos: Support more betfrom value [#Redmine: 80687]
		- 20171020@Kos: Support new platform New Asia [#Redmine: 85203]
		- 20180205@Kos: Add more condition for SB in Parlay [#Redmine: 90492]
		- 20180226@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180305@Kos: Don't support Live Casino anymore [#Redmine: 85965]
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]
		- 20180329@Kos: Support Fast Market 2 [#Redmine: 90879]
		- 20180510@Kos: Support Keno 6 new Mini Games [#Redmine: 94829]
		- 20180806@Kos: Don't support Racing anymore [#Redmine: 99378]
		- 20181102@Kos: Remove DBLIC linked server [#Redmine: 103660]
		- 20181113@Kos: Support new platform 'o' Mobile App [#Redmine: 104521]
		- 20181210@Kos: Support new platform 'c' Mobile China View [#Redmine: 106088]
		- 20190401@Kos: Don't support Microgaming Live Casino and Microgaming RNG Casino anymore [#Redmine: 107704]
					- Remove params @ShowMGCLC and @ShowMGCRNG
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190524@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
					- Remove params @SumWinLostUSD, @SumWinLostEUR, @SumWinLostGBP, ...
		- 20190829@Kos: Support betfrom Deeplink 't' [Redmine: #115448]
					- Remove betfrom 's' and 'y'
		- 20191216@Kos: Support betfrom Licensee Odds Feed 'v' [Redmine: #125553]
		- 20191226@Kos: Support betfrom Native Apps '0' [Redmine: #125824]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200302@Kos: Support 3 new betfrom [Redmine: #129253]
		- 20200402@Kos: Support Table Games [Redmine: #131447]
		- 20200416@Kos: Support Indo 4D [Redmine: #130859]
		- 20200425@Kos: Support status Delay Payout [Redmine: #132629]
		- 20200502@Kos: Support Table Game Half Won Half Lose [Redmine: #133323]
		- 20200525@Kos: Support show licensee transaction ID [Redmine: #134629]
		- 20200619@Kos: Support 3 new eGamer betfrom [Redmine: #136107]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]

	Param's Explanation:
		+ @DrawFilter:
			- 1: Normal
			- 2: No Draw
			- 3: No Draw for Turnover only
		+ @PlatformType:
			- 0 - All: All
			- 1 - Asia: d (mobile), g (MG Download only)
			- 2 - China: a (dep-Singbet), z (dep2-SingBet)
			- 3 - Euro: e (Europe), u (dep-Euro)
			- 4 - WAP: m (dep-wap)
			- 5 - Smart Site: l (dep-smart)
			- 6 - Tablet: r (dep2-tablet)
			- 7 - New Asia: x (dep2-Asia)
			- 8 - Mobile App: o (dep-New Mobile APP)
			- 9 - Mobile China View: c (dep-MCV)
			- 10 - Deep Link: t (Licensee-Deeplink)
			- 11 - Native App: 0 (Native App)
			- 12 - E-Sports Web Desktop: 1 (E-Sports Web Desktop), 4 (eGamer Desktop)
			- 13 - E-Sports Web Mobile: 2 (E-Sports Web Mobile), 5 (eGamer Mobile)
			- 14 - E-Sports App: 3 (E-Sports App), 6 (eGamer App)
			- 88 - Others: v (Licensee Odds Feed)

	Sample call:
		DECLARE @p17 INT
		DECLARE @p18 MONEY
		DECLARE @p19 MONEY
		DECLARE @p20 MONEY
		DECLARE @p21 MONEY
		DECLARE @p22 MONEY
		DECLARE @p23 MONEY
		DECLARE @p24 MONEY
		DECLARE @p25 MONEY
		DECLARE @p26 MONEY
		DECLARE @p27 MONEY
		DECLARE @p28 MONEY
		DECLARE @p29 MONEY
		DECLARE @p30 MONEY
		DECLARE @p31 MONEY
		DECLARE @p32 MONEY
		DECLARE @p33 MONEY
		EXEC [Lrf_BetList_PlatformWinLoss_Mem] @AgentList=N'<ROOT><Agent AgentId="791088" Currency="6"/><Agent AgentId="860379" Currency="6"/></ROOT>',@custid=16052548,
			@FromDate='2016-03-01 00:00:00',@ToDate='2016-03-30 00:00:00',
			@MoveBetsDay='2016-03-20 00:00:00',@BalanceUpDay='2016-03-19 00:00:00',
			@showSB=1,@showNG=0,@ShowVS=1,@ShowCS=0,@ShowKN=1,@ShowVB=1,
			@showBA=0,@PageSize=2147483646,@PageIndex=1,@totalrows=@p17 OUTPUT,@SumWinlost=@p18 OUTPUT,
			@SumLicenseeWL=@p19 OUTPUT,@SumComm=@p20 OUTPUT,@SumPlayerComm=@p21 OUTPUT,@SumWinlostUSD=@p22 OUTPUT,
			@SumLicenseeWLUSD=@p23 OUTPUT,@SumCommUSD=@p24 OUTPUT,@SumPlayerCommUSD=@p25 OUTPUT,
			@SumWinlostEUR=@p26 OUTPUT,@SumLicenseeWLEUR=@p27 OUTPUT,@SumCommEUR=@p28 OUTPUT,@SumPlayerCommEUR=@p29 OUTPUT,
			@SumWinlostGBP=@p30 OUTPUT,@SumLicenseeWLGBP=@p31 OUTPUT,@SumCommGBP=@p32 OUTPUT,@SumPlayerCommGBP=@p33 OUTPUT,
			@DrawFilter=1,@PlatformType=0
		SELECT @p17, @p18, @p19, @p20, @p21, @p22, @p23, @p24, @p25, @p26, @p27, @p28, @p29, @p30, @p31, @p32, @p33
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
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH

	-- Get SportBetTypeMatrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 3, 5, 6, 8, 22, 24, 27, 28, 40, 43)

	DELETE @SportBettype 
	WHERE ProductID = 1 AND Bettype IN (901, 902, 903, 904)	-- Don't support BetTrade

	DELETE FROM @SportBettype
	WHERE ProductID = CASE WHEN @ShowSB	= 0 AND @ShowBA = 0 THEN 1 END
		OR ProductID = CASE WHEN @ShowNG		= 0 THEN 3 END
		OR ProductID = CASE WHEN @ShowVS		= 0 THEN 5 END
		OR ProductID = CASE WHEN @ShowCS		= 0 THEN 6 END
		OR ProductID = CASE WHEN @ShowKN		= 0 THEN 8 END
		OR ProductID = CASE WHEN @ShowVB		= 0 THEN 22 END
		OR ProductID = CASE WHEN @ShowFW		= 0 THEN 24 END
		OR ProductID = CASE WHEN @ShowVS2		= 0 THEN 27 END
		OR ProductID = CASE WHEN @ShowLT		= 0 THEN 28 END
		OR ProductID = CASE WHEN @ShowTG		= 0 THEN 40 END
		OR ProductID = CASE WHEN @ShowI4D		= 0 THEN 43 END

	DECLARE @BetFrom AS TABLE (
		BetFrom	NVARCHAR(1)
	)

	-- Asia
	IF @PlatformType IN (0, 1)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT 'd' UNION ALL
		SELECT 'g'
	END

	-- China
	IF @PlatformType IN (0, 2)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT 'a' UNION ALL
		SELECT 'z'
	END

	-- Euro
	IF @PlatformType IN (0, 3)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT 'e' UNION ALL
		SELECT 'u'
	END

	-- WAP
	IF @PlatformType IN (0, 4)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT 'm'
	END

	-- Smart Site
	IF @PlatformType IN (0, 5)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT 'l'
	END

	-- Tablet
	IF @PlatformType IN (0, 6)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT 'r'
	END

	-- New Asia
	IF @PlatformType IN (0, 7)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT 'x'
	END

	-- Mobile App
	IF @PlatformType IN (0, 8)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT 'o'
	END

	-- Mobile China View
	IF @PlatformType IN (0, 9)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT 'c'
	END

	-- Deeplink
	IF @PlatformType IN (0, 10)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT 't'
	END

	-- Native App
	IF @PlatformType IN (0, 11)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT '0'
	END

	-- E-Sports Web Desktop
	IF @PlatformType IN (0, 12)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT '1' UNION ALL
		SELECT '4'
	END

	-- E-Sports Web Mobile
	IF @PlatformType IN (0, 13)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT '2' UNION ALL
		SELECT '5'
	END

	-- E-Sports App
	IF @PlatformType IN (0, 14)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT '3' UNION ALL
		SELECT '6'
	END

	-- Others
	IF @PlatformType IN (0, 88)
	BEGIN
		INSERT INTO @BetFrom (BetFrom)
		SELECT 'v'
	END

	DECLARE @Data AS TABLE (
		SportType			INT,
		TransId				BIGINT,
		BetId				BIGINT,
		BetType				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Modds				MONEY,
		OddsType			TINYINT,
		Odds				MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		BetTeam				NVARCHAR(20),
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		RefNo				BIGINT,
		TransDate			DATETIME,
		WinLostDate			DATETIME,
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
		Currency			INT,
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

	DECLARE @BABetList AS TABLE (
		TransId			BIGINT,
		BetId			BIGINT,
		BetType			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		BetTeam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNo			BIGINT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(50),
		Currency		INT,
		MatchId			INT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		OddsSpread		MONEY
	)

	DECLARE @ExchangeRate TABLE (
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	DECLARE @fdate SMALLDATETIME,
		@tdate SMALLDATETIME

	SELECT @fdate = @FromDate,
		@tdate = @ToDate

	DECLARE @TempFromDate SMALLDATETIME
	DECLARE @TempToDate SMALLDATETIME

	IF @tdate > @MoveBetsDay
	BEGIN
		IF @fdate <= @MoveBetsDay
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @fdate

		-- Get BA Tickets
		INSERT INTO @BABetList
		SELECT
			b.transid,
			ISNULL(b.betid, 0) AS BetId,
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
			b.refno,
			b.transdate,
			b.winlostdate,
			(b.winlost - b.actual_stake) AS WinLost,
			0 AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.currency,
			b.matchid,
			ISNULL(b.betcheck, '') AS BetCheck,
			ISNULL(b.transdesc, '') AS transdesc,
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
			ISNULL(b.oddsspread, 0) AS OddsSpread
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS ba WITH (NOLOCK) ON b.transid = ba.transid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @tdate
			AND b.custid = @CustId
			AND b.statusID IN (111, 112, 113)
			AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO @Data
			SELECT
				m.sporttype,
				b.TransId,
				b.BetId,
				b.BetType,
				b.Hdp1,
				b.Hdp2,
				b.Modds,
				b.OddsType,
				b.Odds,
				b.Stake,
				b.Actual_Stake,
				b.BetTeam,
				b.Status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				b.RefNo,
				b.TransDate,
				b.WinLostDate,
				b.WinLost,
				b.LicenseeWL,
				b.Comm,
				b.PlayerComm,
				b.LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Ip,
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
				b.BetCheck,
				b.TransDesc,
				b.BetdaqId,
				b.ExtraInfo,
				b.OriginalStake,
				b.OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				b.OddsSpread
			FROM
				@BABetList AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1

			-- Outright
			INSERT INTO @Data
			SELECT
				l.sporttype,
				b.TransId,
				b.BetId,
				b.BetType,
				0 AS hdp1,
				0 AS hdp2,
				b.Modds,
				0 AS OddsType,
				b.Odds,
				b.Stake,
				b.Actual_Stake,
				'' AS BetTeam,
				b.Status,
				0 AS SettlementStatus,
				b.RefNo,
				b.TransDate,
				b.WinLostDate,
				b.WinLost,
				b.LicenseeWL,
				b.Comm,
				b.PlayerComm,
				0 AS LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Ip,
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
				b.Currency,
				'' AS ShowTime,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				b.ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				@BABetList AS b
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.MatchId = m.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + System Parlay
			INSERT INTO @Data
			SELECT
				0 AS SportType,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.BetId, 0) = 0 THEN b.transid
							ELSE b.BetId
						END
				END AS TransId,
				b.BetId,
				b.BetType,
				b.Hdp1,
				b.Hdp2,
				b.Modds,
				0 AS OddsType,
				b.Odds,
				b.Stake,
				b.Actual_Stake,
				b.BetTeam,
				b.Status,
				0 AS SettlementStatus,
				b.RefNo,
				b.TransDate,
				b.WinLostDate,
				b.WinLost,
				b.LicenseeWL,
				b.Comm,
				b.PlayerComm,
				b.LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Ip,
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
				b.Currency,
				'' AS ShowTime,
				b.BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				b.ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM @BABetList AS b
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1
				AND sbt.EventType = 0
				AND b.matchid IN (9, 29)
		END

		-- Sportsbook, RNG Casino, Keno, Betradar Virtual Sports, Lottery, Table Games, Indo 4D (EventType = 0)
		IF @ShowSB = 1 OR @ShowCS = 1 OR @ShowKN = 1 OR @ShowVS2 = 1 OR @ShowLT = 1 OR @ShowTG = 1 OR @ShowI4D = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN 0
					WHEN sbt.ProductID = 6 THEN 251
					WHEN sbt.ProductID = 8 THEN 202
					WHEN sbt.ProductID = 28 THEN 220
					WHEN sbt.ProductID IN (40, 43) THEN b.matchid
					ELSE 0
				END AS Sporttype,
				CASE
					WHEN (b.bettype = 29 AND ISNULL(b.betid, 0) > 0) THEN b.betid
					ELSE b.transid
				END AS TransId,
				ISNULL(b.betid, 0) AS BetId,
				b.bettype,
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN b.hdp1
					ELSE 0
				END AS Hdp1,
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN b.hdp2
					ELSE 0
				END AS Hdp1,
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN b.modds
					ELSE 0
				END AS Modds,
				0 AS OddsType,
				CASE
					WHEN sbt.ProductID IN (1, 8, 27, 28, 40, 43) THEN b.odds
					ELSE 0
				END AS Odds,
				b.stake,
				b.actual_stake,
				CASE 
					WHEN sbt.ProductID IN (1, 27) THEN b.betteam
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
				CASE 
					WHEN sbt.ProductID = 1 THEN b.liveindicator
					ELSE 0
				END AS LiveIndicator,
				CASE 
					WHEN sbt.ProductID = 1 THEN b.livehomescore
					ELSE 0
				END AS LiveHomeScore,
				CASE 
					WHEN sbt.ProductID = 1 THEN b.liveawayscore
					ELSE 0
				END AS LiveAwayScore,
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
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN ISNULL(b.betcheck, '')
					WHEN sbt.ProductId = 8 THEN ISNULL(b.comstatus, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN sbt.ProductID IN (8, 28, 40, 43) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				CASE
					WHEN sbt.ProductID = 1 THEN ISNULL(b.ExtraInfo, '')
					ELSE ''
				END AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.EventType = 0
				AND (sbt.ProductID IN (8, 27, 28, 40, 43)
					OR (sbt.ProductID = 6 AND sbt.SubProduct = '')
					OR (sbt.ProductID = 1 AND @ShowSB = 1))		-- check in case of @ShowBA = 1
				AND b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113)
				AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)
				AND b.transid NOT IN (SELECT TransId FROM @BABetList) -- Exclude BA tickets
		END

		-- Sportsbook, Number Game, Virtual Sports, Betradar Virtual Sports (EventType = 1)
		IF @ShowSB = 1 OR @ShowNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
				b.bettype,
				CASE
					WHEN sbt.ProductId IN (1, 3, 5, 27) THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN sbt.ProductId IN (1, 3, 5, 27) THEN b.hdp2
					ELSE 0
				END AS hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				CASE 
					WHEN sbt.ProductID = 1 THEN ISNULL(m.SettlementStatus, 0)
					ELSE 0
				END AS SettlementStatus,
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
				m.GlobalShowTime AS EventDate,
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
				CASE
					WHEN sbt.ProductId = 1 THEN b.betcheck
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN sbt.ProductId IN (1, 27) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				CASE
					WHEN sbt.ProductId = 1 THEN ISNULL(b.betdaqid, -1)
					ELSE -1
				END AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN sbt.ProductId = 1 AND b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				CASE
					WHEN sbt.ProductID = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN sbt.ProductID = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode,
				CASE
					WHEN sbt.ProductID = 1 THEN ISNULL(b.oddsspread, 0)
					ELSE 0
				END AS OddsSpread
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.EventType = 1
				AND (sbt.ProductID IN (3, 5, 27)
					OR (sbt.ProductID = 1 AND @ShowSB = 1))		-- check in case of @ShowBA = 1
				AND b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113)
				AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)
				AND b.transid NOT IN (SELECT Transid FROM @BABetList) -- Exclude BA tickets
		END

		-- Outright (EventType = 2)
		IF @ShowSB = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				l.sporttype,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
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
				- (b.winlost - b.actual_stake) AS LicenseeWL,
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
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
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
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE b.bettype = 10
				AND b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113)
				AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)
				AND b.transid NOT IN (SELECT Transid FROM @BABetList) -- Exclude BA tickets
		END

		-- Virtual Sports (EventType = 3)
		IF @ShowVS = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				r.SportType,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
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
				r.Betstatus,
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
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.EventType = 3
				AND sbt.ProductID = 5
				AND b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113)
				AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)

		END

		-- RNG Casino Single Wallet, Macau Games, Fishing World
		IF @ShowCS = 1 OR @ShowVB = 1 OR @ShowFW = 1
		BEGIN
			-- Up to yesterday settled ticket
			INSERT INTO @Data
			SELECT
				CASE
					WHEN sbt.ProductID = 6 THEN b.matchid
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 24 THEN 219
					ELSE 0
				END AS Sporttype,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS Modds,
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
				CASE
					WHEN sbt.ProductID IN (6, 22, 24) THEN b.transdesc
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
			WHERE (sbt.ProductID IN (22, 24)
					OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
				AND b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.winlostdate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- not yesterday and today
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113)
				AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)

			IF @tdate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)				-- yesterday
				AND @TempFromDate <= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- today
			BEGIN
				-- Yesterday and today settled ticket
				INSERT INTO @Data
				SELECT
					CASE
						WHEN sbt.ProductID = 6 THEN b.matchid
						WHEN sbt.ProductID = 22 THEN 212
						WHEN sbt.ProductID = 24 THEN 219
						ELSE 0
					END AS Sporttype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.bettype,
					0 AS Hdp1,
					0 AS Hdp2,
					0 AS Modds,
					0 AS OddsType,
					0 AS Odds,
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
					SUM(brng.comm) AS comm,
					SUM(brng.playercomm) AS playercomm,
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
					CASE
						WHEN sbt.ProductID IN (6, 22, 24) THEN b.transdesc
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
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				WHERE (sbt.ProductID IN (22, 24)
						OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
					AND b.winlostdate BETWEEN @TempFromDate AND @tdate
					AND b.winlostdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0) 
						AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- yesterday and today
					AND b.custid = @CustId
					AND brng.statusID <> 0
					AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)
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
	END

	IF @fdate <= @MoveBetsDay AND @tdate >= @BalanceUpDay
	BEGIN
		IF @tdate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @tdate

		IF @BalanceUpDay < @fdate
			SELECT @BalanceUpDay = @fdate

		-- Get BA Tickets
		DELETE FROM @BABetList

		INSERT INTO @BABetList
		SELECT
			b.transid,
			ISNULL(b.betid, 0) AS BetId,
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
			b.refno,
			b.transdate,
			b.winlostdate,
			(b.winlost - b.actual_stake) AS WinLost,
			0 AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.currency,
			b.matchid,
			ISNULL(b.betcheck, '') AS BetCheck,
			ISNULL(b.transdesc, '') AS transdesc,
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
			ISNULL(b.oddsspread, 0) AS OddsSpread
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk AS ba WITH (NOLOCK) ON b.transid = ba.transid
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
			AND b.custid = @CustId
			AND b.statusID IN (111, 112, 113)
			AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO @Data
			SELECT
				m.sporttype,
				b.TransId,
				b.BetId,
				b.BetType,
				b.Hdp1,
				b.Hdp2,
				b.Modds,
				b.OddsType,
				b.Odds,
				b.Stake,
				b.Actual_Stake,
				b.BetTeam,
				b.Status,
				0 AS SettlementStatus,
				b.RefNo,
				b.TransDate,
				b.WinLostDate,
				b.WinLost,
				b.LicenseeWL,
				b.Comm,
				b.PlayerComm,
				b.LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Ip,
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
				b.TransDesc,
				b.BetdaqId,
				b.ExtraInfo,
				b.OriginalStake,
				b.OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				b.OddsSpread
			FROM
				@BABetList AS b
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1

			-- Outright
			INSERT INTO @Data
			SELECT
				l.sporttype,
				b.TransId,
				b.BetId,
				b.BetType,
				0 AS hdp1,
				0 AS hdp2,
				b.Modds,
				0 AS OddsType,
				b.Odds,
				b.Stake,
				b.Actual_Stake,
				'' AS BetTeam,
				b.Status,
				0 AS SettlementStatus,
				b.RefNo,
				b.TransDate,
				b.WinLostDate,
				b.WinLost,
				b.LicenseeWL,
				b.Comm,
				b.PlayerComm,
				0 AS LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Ip,
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
				b.Currency,
				'' AS ShowTime,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				b.ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				@BABetList AS b
				INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + System Parlay
			INSERT INTO @Data
			SELECT
				0 AS SportType,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.BetId, 0) = 0 THEN b.transid
							ELSE b.BetId
						END
				END AS TransId,
				b.BetId,
				b.BetType,
				b.Hdp1,
				b.Hdp2,
				b.Modds,
				0 AS OddsType,
				b.Odds,
				b.Stake,
				b.Actual_Stake,
				b.BetTeam,
				b.Status,
				0 AS SettlementStatus,
				b.RefNo,
				b.TransDate,
				b.WinLostDate,
				b.WinLost,
				b.LicenseeWL,
				b.Comm,
				b.PlayerComm,
				b.LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Ip,
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
				b.Currency,
				'' AS ShowTime,
				b.BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				b.ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				@BABetList AS b
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
			WHERE
				sbt.ProductID = 1
				AND sbt.EventType = 0
				AND b.matchid IN (9, 29)
		END

		-- Sportsbook, RNG Casino, Keno, Macau Games, Fishing World, Betradar Virtual Sports, Lottery, Table Games, Indo 4D (EventType = 0)
		IF @ShowSB = 1 OR @ShowCS = 1 OR @ShowKN = 1 OR @ShowVB = 1 OR @ShowFW = 1 OR @ShowVS2 = 1 OR @ShowLT = 1 OR @ShowTG = 1 OR @ShowI4D = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN 0
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN 251
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.matchid
					WHEN sbt.ProductID = 8 THEN 202
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 24 THEN 219
					WHEN sbt.ProductID = 28 THEN 220
					WHEN sbt.ProductID IN (40, 43) THEN b.matchid
					ELSE 0
				END AS Sporttype,
				CASE
					WHEN (b.bettype = 29 AND ISNULL(b.betid, 0) > 0) THEN b.betid
					ELSE b.transid
				END AS TransId,
				ISNULL(b.betid, 0) AS BetId,
				b.bettype,
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN b.hdp1
					ELSE 0
				END AS Hdp1,
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN b.hdp2
					ELSE 0
				END AS Hdp1,
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN b.modds
					ELSE 0
				END AS Modds,
				0 AS OddsType,
				CASE
					WHEN sbt.ProductID IN (1, 8, 27, 28, 40, 43) THEN b.odds
					ELSE 0
				END AS Odds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN b.betteam
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
				CASE 
					WHEN sbt.ProductID = 1 THEN b.liveindicator
					ELSE 0
				END AS LiveIndicator,
				CASE 
					WHEN sbt.ProductID = 1 THEN b.livehomescore
					ELSE 0
				END AS LiveHomeScore,
				CASE 
					WHEN sbt.ProductID = 1 THEN b.liveawayscore
					ELSE 0
				END AS LiveAwayScore,
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
					WHEN sbt.ProductID IN (1, 27) THEN ISNULL(b.betcheck, '')
					WHEN sbt.ProductID = 8 THEN ISNULL(b.comstatus, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.transdesc
					WHEN sbt.ProductID IN (8, 22, 24, 28, 40, 43) THEN b.transdesc
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				CASE
					WHEN sbt.ProductID = 1 THEN ISNULL(b.ExtraInfo, '')
					ELSE ''
				END AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.EventType = 0
				AND (sbt.ProductID IN (6, 8, 22, 24, 27, 28, 40, 43)
					OR (sbt.ProductID = 1 AND @ShowSB = 1))		-- check in case of @ShowBA = 1
				AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113)
				AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)
				AND b.transid NOT IN (SELECT Transid FROM @BABetList) -- Exclude BA tickets
		END

		-- Sportsbook, Number Game, Virtual Sports, Betradar Virtual Sports (EventType = 1)
		IF @ShowSB = 1 OR @ShowNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
				b.bettype,
				CASE
					WHEN sbt.ProductId IN (1, 3, 5, 27) THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN sbt.ProductId IN (1, 3, 5, 27) THEN b.hdp2
					ELSE 0
				END AS hdp2,
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
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CASE
					WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE ''
				END AS ShowTime,
				CASE
					WHEN sbt.ProductId = 1 THEN b.betcheck
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN sbt.ProductId IN (1, 27) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				CASE
					WHEN sbt.ProductId = 1 THEN ISNULL(b.betdaqid, -1)
					ELSE -1
				END AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN sbt.ProductId = 1 AND b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				CASE
					WHEN sbt.ProductID = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN sbt.ProductID = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode,
				CASE
					WHEN sbt.ProductID = 1 THEN ISNULL(b.oddsspread, 0)
					ELSE 0
				END AS OddsSpread
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.EventType = 1
				AND (sbt.ProductID IN (3, 5, 27)
					OR (sbt.ProductID = 1 AND @ShowSB = 1))		-- check in case of @ShowBA = 1
				AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113)
				AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)
				AND b.transid NOT IN (SELECT Transid FROM @BABetList) -- Exclude BA tickets
		END

		-- Outright (EventType = 2)
		IF @ShowSB = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				l.sporttype,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
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
				- (b.winlost - b.actual_stake) AS LicenseeWL,
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
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
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
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE b.bettype = 10
				AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113)
				AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)
				AND b.transid NOT IN (SELECT Transid FROM @BABetList) -- Exclude BA tickets
		END

		-- Virtual Sports (EventType = 3)
		IF @ShowVS = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				r.SportType,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
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
				r.Betstatus,
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
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.EventType = 3
				AND sbt.ProductID = 5
				AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.custid = @CustId
				AND b.statusID IN (111, 112, 113)
				AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)

		END
	END

	IF @fdate < @BalanceUpDay
	BEGIN
		IF @tdate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @tdate

		DELETE FROM @BABetList

		-- Get BA Tickets
		INSERT INTO @BABetList
		SELECT
			b.transid,
			ISNULL(b.betid, 0) AS BetId,
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
			b.refno,
			b.transdate,
			b.winlostdate,
			(b.winlost - b.actual_stake) AS WinLost,
			0 AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.currency,
			b.matchid,
			ISNULL(b.betcheck, '') AS BetCheck,
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
			ISNULL(b.oddsspread, 0) AS OddsSpread
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk AS ba WITH (NOLOCK) ON b.transid = ba.transid
		WHERE
			b.winlostdate BETWEEN @fdate AND @TempToDate
			AND b.custid = @CustId
			AND b.ruben = 1
			AND b.status NOT IN ('VOID','REJECT','REFUND')
			AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO @Data
			SELECT
				m.sporttype,
				b.TransId,
				b.BetId,
				b.BetType,
				b.Hdp1,
				b.Hdp2,
				b.Modds,
				b.OddsType,
				b.Odds,
				b.Stake,
				b.Actual_Stake,
				b.BetTeam,
				b.Status,
				0 AS SettlementStatus,
				b.RefNo,
				b.TransDate,
				b.WinLostDate,
				b.WinLost,
				b.LicenseeWL,
				b.Comm,
				b.PlayerComm,
				b.LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Ip,
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
				b.BetCheck,
				b.TransDesc,
				b.BetdaqId,
				b.ExtraInfo,
				b.OriginalStake,
				b.OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				b.OddsSpread
			FROM
				@BABetList AS b
				INNER JOIN bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1

			-- Outright
			INSERT INTO @Data
			SELECT
				l.sporttype,
				b.TransId,
				b.BetId,
				b.BetType,
				0 AS hdp1,
				0 AS hdp2,
				b.Modds,
				0 AS OddsType,
				b.Odds,
				b.Stake,
				b.Actual_Stake,
				'' AS BetTeam,
				b.Status,
				0 AS SettlementStatus,
				b.RefNo,
				b.TransDate,
				b.WinLostDate,
				b.WinLost,
				b.LicenseeWL,
				b.Comm,
				b.PlayerComm,
				0 AS LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Ip,
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
				b.Currency,
				'' AS ShowTime,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				b.ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				@BABetList AS b
				INNER JOIN bodb_archive.dbo.outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + System parlay
			INSERT INTO @Data
			SELECT
				0 AS SportType,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.BetId, 0) = 0 THEN b.transid
							ELSE b.BetId
						END
				END AS TransId,
				b.BetId,
				b.BetType,
				b.Hdp1,
				b.Hdp2,
				b.Modds,
				0 AS OddsType,
				b.Odds,
				b.Stake,
				b.Actual_Stake,
				b.BetTeam,
				b.Status,
				0 AS SettlementStatus,
				b.RefNo,
				b.TransDate,
				b.WinLostDate,
				b.WinLost,
				b.LicenseeWL,
				b.Comm,
				b.PlayerComm,
				b.LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Ip,
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
				b.Currency,
				'' AS ShowTime,
				b.BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				b.ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				@BABetList AS b
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				sbt.ProductID = 1
				AND sbt.EventType = 0
				AND b.matchid IN (9, 29)
		END

		-- Sportsbook, RNG Casino, Keno, Macau Games, Fishing World, Betradar Virtual Sports, Lottery, Table Games, Indo 4D (EventType = 0)
		IF @ShowSB = 1 OR @ShowCS = 1 OR @ShowKN = 1 OR @ShowVB = 1 OR @ShowFW = 1 OR @ShowVS2 = 1 OR @ShowLT = 1 OR @ShowTG = 1 OR @ShowI4D = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN 0
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN 251
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.matchid
					WHEN sbt.ProductID = 8 THEN 202
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 24 THEN 219
					WHEN sbt.ProductID = 28 THEN 220
					WHEN sbt.ProductID IN (40, 43) THEN b.matchid
					ELSE 0
				END AS Sporttype,
				CASE
					WHEN (b.bettype = 29 AND ISNULL(b.betid, 0) > 0) THEN b.betid
					ELSE b.transid
				END AS TransId,
				ISNULL(b.betid, 0) AS BetId,
				b.bettype,
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN b.hdp1
					ELSE 0
				END AS Hdp1,
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN b.hdp2
					ELSE 0
				END AS Hdp1,
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN b.modds
					ELSE 0
				END AS Modds,
				0 AS OddsType,
				CASE
					WHEN sbt.ProductID IN (1, 8, 27, 28, 40, 43) THEN b.odds
					ELSE 0
				END AS Odds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID IN (1, 27) THEN b.betteam
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
				CASE 
					WHEN sbt.ProductID = 1 THEN b.liveindicator
					ELSE 0
				END AS LiveIndicator,
				CASE 
					WHEN sbt.ProductID = 1 THEN b.livehomescore
					ELSE 0
				END AS LiveHomeScore,
				CASE 
					WHEN sbt.ProductID = 1 THEN b.liveawayscore
					ELSE 0
				END AS LiveAwayScore,
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
					WHEN sbt.ProductID IN (1, 27) THEN ISNULL(b.betcheck, '')
					WHEN sbt.ProductID = 8 THEN ISNULL(b.comstatus, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.transdesc
					WHEN sbt.ProductID IN (8, 22, 24, 28, 40, 43) THEN b.transdesc
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				CASE
					WHEN sbt.ProductID = 1 THEN ISNULL(b.ExtraInfo, '')
					ELSE ''
				END AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.EventType = 0
				AND (sbt.ProductID IN (6, 8, 22, 24, 27, 28, 40, 43)
					OR (sbt.ProductID = 1 AND @ShowSB = 1))		-- check in case of @ShowBA = 1
				AND b.winlostdate BETWEEN @fdate AND @TempToDate
				AND b.custid = @CustId
				AND b.ruben = 1
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
				AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)
				AND b.transid NOT IN (SELECT Transid FROM @BABetList) -- Exclude BA tickets
		END

		-- Sportsbook, Number Game, Virtual Sports, Betradar Virtual Sports (EventType = 1)
		IF @ShowSB = 1 OR @ShowNG = 1 OR @ShowVS = 1 OR @ShowVS2 = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
				b.bettype,
				CASE
					WHEN sbt.ProductId IN (1, 3, 5, 27) THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN sbt.ProductId IN (1, 3, 5, 27) THEN b.hdp2
					ELSE 0
				END AS hdp2,
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
				m.GlobalShowTime AS EventDate,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CASE
					WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE ''
				END AS ShowTime,
				CASE
					WHEN sbt.ProductId = 1 THEN b.betcheck
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN sbt.ProductId IN (1, 27) THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				CASE
					WHEN sbt.ProductId = 1 THEN ISNULL(b.betdaqid, -1)
					ELSE -1
				END AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN sbt.ProductId = 1 AND b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				CASE
					WHEN sbt.ProductID = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN sbt.ProductID = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode,
				CASE
					WHEN sbt.ProductID = 1 THEN ISNULL(b.oddsspread, 0)
					ELSE 0
				END AS OddsSpread
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.EventType = 1
				AND (sbt.ProductID IN (3, 5, 27)
					OR (sbt.ProductID = 1 AND @ShowSB = 1))		-- check in case of @ShowBA = 1
				AND b.winlostdate BETWEEN @fdate AND @TempToDate
				AND b.custid = @CustId
				AND b.ruben = 1
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
				AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)
				AND b.transid NOT IN (SELECT Transid FROM @BABetList) -- Exclude BA tickets
		END

		-- Outright (EventType = 2)
		IF @ShowSB = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				l.sporttype,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
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
				- (b.winlost - b.actual_stake) AS LicenseeWL,
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
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
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
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
			WHERE b.bettype = 10
				AND b.winlostdate BETWEEN @fdate AND @TempToDate
				AND b.custid = @CustId
				AND b.ruben = 1
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
				AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)
				AND b.transid NOT IN (SELECT Transid FROM @BABetList) -- Exclude BA tickets
		END

		-- Virtual Sports (EventType = 3)
		IF @ShowVS = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				r.SportType,
				b.transid,
				ISNULL(b.betid, 0) AS BetId,
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
				r.Betstatus,
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
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN bodb_Archive.dbo.VSRaceInfo_bk AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.EventType = 3
				AND sbt.ProductID = 5
				AND b.winlostdate BETWEEN @fdate AND @TempToDate
				AND b.custid = @CustId
				AND b.ruben = 1
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
				AND b.betfrom IN (SELECT BetFrom FROM @BetFrom)
		
		END
	END

	-- Exclude draw for no draw option (2)
	DELETE FROM @Data
	WHERE @DrawFilter = 2 AND Status = 'DRAW' AND ABS(Modds) <> 0.25

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode		BIGINT,
			TransId		BIGINT,
			Stake		MONEY,
			WinLost		MONEY,
			LicenseeWL	MONEY,
			Comm		MONEY,
			PlayerComm	MONEY
		)

		-- Prepare temp table
		INSERT INTO @RefCodeTmp
		SELECT
			RefCode,
			MIN(TransId) AS TransId,
			SUM(Stake) AS Stake,
			SUM(WinLost) AS WinLost,
			SUM(LicenseeWL) AS LicenseeWL,
			SUM(Comm) AS Comm,
			SUM(PlayerComm) AS PlayerComm
		FROM @Data
		WHERE RefCode <> 0
		GROUP BY RefCode
		HAVING COUNT(*) > 1

		IF EXISTS (SELECT 1 FROM @RefCodeTmp)
		BEGIN
			-- Update data for summmary ticket
			UPDATE b
			SET
				b.Stake = r.Stake,
				b.WinLost = r.WinLost,
				b.LicenseeWL = r.LicenseeWL,
				b.Comm = r.Comm,
				b.PlayerComm = r.PlayerComm,
				b.WalletType = 0
			FROM @Data AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE @Data
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE @Data
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	DECLARE @Currency	INT

	SELECT @Currency = currency
	FROM dbo.Customer WITH (NOLOCK)
	WHERE custid = @CustId

	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM @Data

	-- Get exchange rate
	INSERT INTO @ExchangeRate
	SELECT
		e.FirstExchangeDateByMonth,
		e.LastExchangeDateByMonth,
		CASE
			WHEN @BaseCurrency = 'MYR' THEN e.MYR
			WHEN @BaseCurrency = 'USD' THEN e.USD
			WHEN @BaseCurrency = 'EUR' THEN e.EUR
			WHEN @BaseCurrency = 'CNY' THEN e.CNY
			WHEN @BaseCurrency = 'IDR' THEN e.IDR
			WHEN @BaseCurrency = 'GBP' THEN e.GBP
			WHEN @BaseCurrency = 'THB' THEN e.THB
			WHEN @BaseCurrency = 'INH' THEN e.INH
			ELSE 1
		END AS Rate
	FROM dbo.Lrf_f_GetSubExchangeDaily(@ExFromDate, @ExToDate) AS e
	WHERE e.ExchangeId = @Currency
		AND EXISTS (SELECT 1 FROM @Data WHERE WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth)

	SELECT
		@TotalRows			= COUNT(b.TransId),
		@SumWinlost			= SUM(b.WinLost		* ISNULL(e.Rate, 1)),
		@SumLicenseeWL		= SUM(b.LicenseeWL	* ISNULL(e.Rate, 1)),
		@SumComm			= SUM(b.Comm		* ISNULL(e.Rate, 1)),
		@SumPlayerComm		= SUM(b.PlayerComm	* ISNULL(e.Rate, 1))
	FROM @Data AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

	DECLARE @RowStart	INT,
		@RowEnd			INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	SELECT
		a.SportType,
		a.TransId,
		a.BetId,
		a.BetType,
		a.Hdp1,
		a.Hdp2,
		a.Modds,
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
	FROM
		(
			SELECT
				ROW_NUMBER () OVER (ORDER BY d.TransDate ASC) AS RowNum,
				d.*
			FROM @Data AS d
		) a
		LEFT JOIN @ExchangeRate AS e ON a.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	WHERE a.RowNum BETWEEN @RowStart AND @RowEnd

	-- Get sub tickets
	DECLARE @BettransDetail TABLE(
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
				FROM @Data AS b
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE sbt.ProductId = 5 AND sbt.EventType = 3)
	BEGIN
		IF @tdate > @MoveBetsDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake * ISNULL(e.Rate, 1) AS Stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.betteam
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @Data AS b ON bm.refno = b.RefNo
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
				LEFT JOIN @ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			WHERE bm.custid = @CustId
				AND sbt.ProductId = 5
				AND sbt.EventType = 3
				AND sbtm.ProductId = 5
				AND sbtm.EventType = 3
		END

		IF @fdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake * ISNULL(e.Rate, 1) AS Stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.betteam
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN @Data AS b ON bm.refno = b.RefNo
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
				LEFT JOIN @ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			WHERE bm.custid = @CustId
				AND sbt.ProductId = 5
				AND sbt.EventType = 3
				AND sbtm.ProductId = 5
				AND sbtm.EventType = 3
		END

		IF @fdate < @BalanceUpDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bm.refno,
				bm.odds,
				bm.stake * ISNULL(e.Rate, 1) AS Stake,
				bm.status,
				bm.apositiontaking,
				bm.bettype,
				bm.Betteam
			FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @Data AS b ON bm.refno = b.RefNo
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
				LEFT JOIN @ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
			WHERE bm.custid = @CustId
				AND sbt.ProductId = 5
				AND sbt.EventType = 3
				AND sbtm.ProductId = 5
				AND sbtm.EventType = 3
		END
	END

	SELECT DISTINCT * FROM @BettransDetail
	ORDER BY RefNo ASC, Bettype ASC
END
GO




GRANT EXECUTE ON [dbo].[Lrf_BetList_PlatformWinLoss_Mem] TO [bodbLicenseeNet]
GO
