/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Statement_Mem]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@ViewSabaCoins	BIT				= 0,
	@Date			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@ProductCode	VARCHAR(200),
	@TransType		TINYINT			= 1,
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@SortType		TINYINT			= 0,		-- TransDate
	@SortOrder		TINYINT			= 1,		-- ASC
	@TotalRows		INT				= 0 OUTPUT,
	@SumStake		MONEY			= 0 OUTPUT,
	@SumWinLost		MONEY			= 0 OUTPUT,
	@SumLicenseeWL	MONEY			= 0 OUTPUT,
	@SumComm		MONEY			= 0 OUTPUT,
	@SumPlayerComm	MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Statement Bet List
	DB: DBACC.bodb02
	Param's Explanation:
		- @TransType:
			- 0: All
			- 1: Won, Lose, Draw
			- 2: Void, Reject, Refund
			- 3: Running, Waiting
		- @SortType:
			- 0: TransDate
			- 1: Stake
			- 2: WinLoss
			- 3: LicenseeWL
		- @SortOrder
			- 1: ASC
			- 2: DESC

	Revisions:
		- 20190905@Kos: Created [Redmine: #116874]
		- 20190923@Kos: Support tickets which have winlostdate in the future [Redmine: #120690]
		- 20191011@Kos: Fix bug translog [Redmine: #120690]
		- 20191031@Kos: Show Running status for Marked tickets [Redmine: 120309]
		- 20191105@Kos: Support Non-peak Hours Promotion [#Redmine: 121121]
		- 20191128@Kos: Hotfix - Change oddsspread data type from SMALLMONEY to MONEY [Redmine: #124483]
		- 20200102@Kos: Support Spadegaming [Redmine: #124103]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200208@Kos: Support Virtual Games [Redmine: #124911]
		- 20200402@Kos: Support Table Games [Redmine: #131447]
		- 20200416@Kos: Support Indo 4D [Redmine: #130859]
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
		- 20210304@Kos: Hotfix - Wrong data for Saba.club Jackpot Contribution and Jackpot Prize tickets [Redmine: #151158]
		- 20210309@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210311@Kos: Support Sports Lottery [Redmine: #150872]
		- 20210415@Kos: Support Habanero [Redmine: #150843]
		- 20210506@Kos: Support WM Live Casino [Redmine: #140944]
		- 20210517@Kos: Support Big Gaming [Redmine: #146773]
		- 20210524@Kos: Support Vgaming [Redmine: #151583]
		- 20210705@Kos: Support Happy 5 Linked Games - Soccer 5 [Redmine: #154898]
		- 20210714@Kos: Support CG [Redmine: #152619]
		- 20210715@Kos: Support Beach Volleyball [Redmine: #157296]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211029@Kos: Decompress IP in bk range [Redmine: 162342]
		- 20211102@Kos: Support AdvantPlay and AdvantPlay Mini [Redmine: #158186]
		- 20220113@Kos: Support new 3rd result API [Redmine: #166047]
		- 20220215@Kos: Support TxId for 3rd products [Redmine: #166706]
		- 20220217@Kos: Support SG Jackpot [Redmine: #167035]
		- 20220227@Kos: Support Virtual Sports 3 [Redmine: #145337]
		- 20220427@Kos: Support Virtual Games result [Redmine: #170997]
		- 20220428@Kos: Support Bitcoin [RedmineID: #160160]
		- 20220512@Kos: Support FGG [Redmine: #167897]
		- 20220527@Kos: Support MaxGame [RedmineID: #172919]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20221116@Kos: Support Player Tips [Redmine: 180590]
		- 20230119@Kos: Support Jili [Redmine: 182914]
		- 20230328@Kos: Remove inactive products CB, FW, GDG [Redmine: 181424]
		- 20230404@Kos: Extend betfrom length [Redmine: #178059]
		- 20230602@Kos: Support YeeBet [Redmine: 187947]
		- 20230629@Kos: Support MG-RNG [Redmine: 189988]
		- 20230803@Kos: Support Virtual Sports 3 [Redmine: 190908]
		- 20231107@Kos: Support SEAL Entertaiment [Redmine: 180648]
		- 20231110@Kos: Support WE Live Casino [Redmine: 196573]
		- 20231227@Kos: Hotfix - cannot view result [Redmine: 198900]
		- 20240102@Kos: Extend data type [Redmine: 198966]
		- 20240129@Kos: Merge VS1, VS2, VS3 into VS [Redmine: 199523]
		- 20240328@Kos: Return LeagueGroupId to hide Saba text [RedmineID: #201283]
		- 20240412@Kos: Support Gaming API [Redmine: 203734]
		- 20240417@Kos: Support Saba Coins [Redmine: 202281]
		- 20240425@Kos: Support Virtual Sports 4 [Redmine: 199347]
		- 20240619@Kos: Hotfix - Missing TranId3rd for Sports Lottery and Virtual Games [Redmine: 206758]
		- 20240919@Kos: Support BetRadar Horse Racing [Redmine: #210808]
		- 20241018@Kos: Enhance match info for Player Tips [Redmine: 210279]
		- 20241028@Kos: Support Virtual Sports 6 [Redmine: 212446]
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]
		- 20250313@Kos: Remove BA [RedmineID: #216882]
		- 20250318@Kos: Support Virtual Sports 5 [Redmine: 207582]
		- 20250320@Kos: Support SabaCoins multiple wallets [Redmine: 215890]
		- 20250801@Kos: Support Playtech Jackpot [#Redmine: 233781]
		- 20250806@Kos: Fix security issue in dynamic query [#Redmine: 227496]
					- Remove input param @Sort
					- Add new input params @SortType TINYINT, @SortOrder TINYINT
		- 20250814@Kos: Hotfix -  Playtech Jackpot [#Redmine: 236105]
		- 20250820@Kos: Support Playtech Live Jackpot [#Redmine: 230078]
		- 20251028@Kelvin: Integrate - Jacktime - Basketball Main Bettype Hybrid Parlay [#Redmine: 242357]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @HasError BIT = 0

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
		SET @HasError = 1
	END CATCH

	-- Get child product list
	IF EXISTS (SELECT 1 FROM dbo.Lrf_f_GroupProduct() WHERE ',' + @ProductCode + ',' LIKE '%,' + GroupProductPrefix + ',%')
	BEGIN
		DECLARE @ChildProductList VARCHAR(500)

		SELECT @ChildProductList = STRING_AGG(ProductPrefix, ',')
		FROM dbo.Lrf_f_GroupProduct()
		WHERE ',' + @ProductCode + ',' LIKE '%,' + GroupProductPrefix + ',%'

		SET @ProductCode = @ProductCode + ',' + @ChildProductList
	END

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, RefTable TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype (ProductID, Bettype, EventType, RefTable, SubProduct)
	SELECT ProductID, BetType, EventType, RefTable, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductCode, @IsTest)
	WHERE BetType NOT IN (904, 914, 997, 999)
		AND BetType NOT BETWEEN 801 AND 806

	CREATE TABLE #Data (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Recommend			INT,
		Currency			SMALLINT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsId				INT,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		PlayerComm			MONEY,
		Comm				MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		SecAcceptFlag		BIT,
		CheckTime			DATETIME,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		BetFrom				NVARCHAR(4),
		LeagueId			INT,
		LeagueGroupId		SMALLINT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		SiteId				VARCHAR(20),
		ProductId			INT,
		EventId				INT,
		Custom1				NVARCHAR(50),
		Custom2				NVARCHAR(50),
		Custom3				NVARCHAR(50),
		Gameid3rd			NVARCHAR(50),
		Tranid3rd			NVARCHAR(200),
		TableID				TINYINT,
		Product				VARCHAR(30),
		SubProduct			VARCHAR(500),
		RefTable			TINYINT,
		EventType			TINYINT
	)

	CREATE TABLE #PagingData (
		RowNum				INT,
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Recommend			INT,
		Currency			SMALLINT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsId				INT,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		PlayerComm			MONEY,
		Comm				MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		SecAcceptFlag		BIT,
		CheckTime			DATETIME,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		BetFrom				NVARCHAR(4),
		LeagueId			INT,
		LeagueGroupId		SMALLINT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		SiteId				VARCHAR(20),
		ProductId			INT,
		EventId				INT,
		Custom1				NVARCHAR(50),
		Custom2				NVARCHAR(50),
		Custom3				NVARCHAR(50),
		Gameid3rd			NVARCHAR(50),
		Tranid3rd			NVARCHAR(200),
		TableID				TINYINT,
		Product				VARCHAR(30),
		SubProduct			VARCHAR(500),
		RefTable			TINYINT,
		EventType			TINYINT
	)

	-- Get ticket detail
	DECLARE @DetailData TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(20),
		APositionTaking SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(50)
	)

	DECLARE @TmpData TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		Status			NVARCHAR(10),
		WinLost			MONEY,
		LicenseeWL		MONEY,
		PlayerComm		MONEY,
		Comm			MONEY,
		OddsSpread		MONEY
	)

	DECLARE @TmpShadow TABLE (CustId INT)

	DECLARE @Currency	INT,
		@Rate			FLOAT	= 1

	IF @ViewSabaCoins = 1		-- View Saba Coins
	BEGIN
		INSERT INTO @TmpShadow (CustId)
		SELECT s.CustID
		FROM dbo.Dep_CustSabaInfo AS m WITH (NOLOCK)
			INNER JOIN dbo.Dep_CustSabaInfo AS s WITH (NOLOCK) ON s.SabaID = m.SabaID
		WHERE m.CustID = @CustId
			AND m.CustType = 0
			AND s.CustType = 1
	END

	IF @HasError = 0
	BEGIN
		DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)
		DECLARE @_Date SMALLDATETIME

		SET @_Date = @Date

		-- bettrans range
		IF @_Date > @MoveBetsDay
		BEGIN
			IF @ViewSabaCoins = 0		-- View real player
			BEGIN
				-- bettrans
				INSERT INTO #Data (
					TransId, RefNo, CustId, Recommend, Currency, BetType, BetId, BetTeam, Hdp1, Hdp2,
					OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, WinLost, LicenseeWL, PlayerComm,
					Comm, Status, SecAcceptFlag, CheckTime, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip,
					BetFrom, MatchId, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
				)
				SELECT
					b.transid,
					b.refno,
					b.custid,
					b.recommend,
					b.currency,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
					b.betteam,
					b.hdp1,
					b.hdp2,
					b.oddsid,
					b.oddstype,
					b.odds,
					b.modds,
					b.oddsspread,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS WinLost,
					- (b.winlost - b.actual_stake) AS LicenseeWL,
					b.playercomm,
					b.comm,
					b.status,
					b.SecAcceptFlag,
					b.checktime,
					b.transdate,
					b.winlostdate,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					b.betfrom,
					b.matchid,
					b.betcheck,
					b.comstatus,
					b.transdesc,
					b.betdaqid,
					b.ExtraInfo,
					b.WalletType,
					ISNULL(b.RefCode, 0) AS RefCode,
					1 AS TableID
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.custid = @CustId
					AND b.winlostdate = @_Date
					AND 1 = CASE
								WHEN @TransType = 0 THEN 1
								WHEN @TransType = 1 AND b.statusID IN (111, 112, 113) THEN 1
								WHEN @TransType = 2 AND b.statusID IN (101, 102, 103) THEN 1
								WHEN @TransType = 3 AND b.statusID IN (0, 1) THEN 1
								WHEN @_Date >= @Yesterday
									AND @TransType IN (1, 3)
									AND s.RefTable IN (1, 2) THEN 1 -- don't care status of casino's summary rows if >= yesterday
								ELSE 0
							END

				IF @TransType IN (0, 3)
				BEGIN
					-- translog
					INSERT INTO #Data (
						TransId, RefNo, CustId, Recommend, Currency, BetType, Odds, Stake, Actual_Stake, Status,
						TransDate, WinLostDate, LiveIndicator, Ip, BetFrom, TransDesc, SiteId, ProductId, EventId, Custom1,
						Custom2, Custom3, Gameid3rd, Tranid3rd, TableID
					)
					SELECT
						tl.translogid AS TransId,
						tl.translogid AS RefNo,
						tl.custid,
						tl.recommend,
						tl.currency,
						tl.gameID AS BetType,
						tl.odds,
						tl.stake,
						tl.actual_stake,
						tl.status,
						tl.transdate,
						tl.transdate AS WinLostDate,
						tl.liveindicator,
						tl.ip,
						tl.betfrom,
						tl.transdesc,
						tl.SiteId,
						tl.productID,
						tl.eventID,
						tl.custom1,
						tl.custom2,
						tl.custom3,
						tl.GameId3rd,
						tl.TranId3rd,
						4 AS TableID
					FROM dbo.translog AS tl WITH (NOLOCK)
					WHERE tl.custid = @CustId
						AND tl.winlostdate = @_Date
						AND tl.statusID IN (0, 1)
				END
			END
			ELSE				-- View Saba Coins
			BEGIN
				-- bettrans
				INSERT INTO #Data (
					TransId, RefNo, CustId, Recommend, Currency, BetType, BetId, BetTeam, Hdp1, Hdp2,
					OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, WinLost, LicenseeWL, PlayerComm,
					Comm, Status, SecAcceptFlag, CheckTime, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip,
					BetFrom, MatchId, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
				)
				SELECT
					b.transid,
					b.refno,
					b.custid,
					b.recommend,
					b.currency,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
					b.betteam,
					b.hdp1,
					b.hdp2,
					b.oddsid,
					b.oddstype,
					b.odds,
					b.modds,
					b.oddsspread,
					b.stake,
					b.actual_stake,
					(b.winlost - b.actual_stake) AS WinLost,
					CASE
						WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
						ELSE - (b.winlost - b.actual_stake)
					END AS LicenseeWL,
					b.playercomm,
					b.comm,
					b.status,
					b.SecAcceptFlag,
					b.checktime,
					b.transdate,
					b.winlostdate,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					b.betfrom,
					b.matchid,
					b.betcheck,
					b.comstatus,
					b.transdesc,
					b.betdaqid,
					b.ExtraInfo,
					b.WalletType,
					ISNULL(b.RefCode, 0) AS RefCode,
					1 AS TableID
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					INNER JOIN @TmpShadow AS ts ON ts.CustId = b.custid
				WHERE b.winlostdate = @_Date
					AND 1 = CASE
								WHEN @TransType = 0 THEN 1
								WHEN @TransType = 1 AND b.statusID IN (111, 112, 113) THEN 1
								WHEN @TransType = 2 AND b.statusID IN (101, 102, 103) THEN 1
								WHEN @TransType = 3 AND b.statusID IN (0, 1) THEN 1
								WHEN @_Date >= @Yesterday
									AND @TransType IN (1, 3)
									AND s.RefTable IN (1, 2) THEN 1 -- don't care status of casino's summary rows if >= yesterday
								ELSE 0
							END

				IF @TransType IN (0, 3)
				BEGIN
					-- translog
					INSERT INTO #Data (
						TransId, RefNo, CustId, Recommend, Currency, BetType, Odds, Stake, Actual_Stake, Status,
						TransDate, WinLostDate, LiveIndicator, Ip, BetFrom, TransDesc, SiteId, ProductId, EventId, Custom1,
						Custom2, Custom3, Gameid3rd, Tranid3rd, TableID
					)
					SELECT
						tl.translogid AS TransId,
						tl.translogid AS RefNo,
						tl.custid,
						tl.recommend,
						tl.currency,
						tl.gameID AS BetType,
						tl.odds,
						tl.stake,
						tl.actual_stake,
						tl.status,
						tl.transdate,
						tl.transdate AS WinLostDate,
						tl.liveindicator,
						tl.ip,
						tl.betfrom,
						tl.transdesc,
						tl.SiteId,
						tl.productID,
						tl.eventID,
						tl.custom1,
						tl.custom2,
						tl.custom3,
						tl.GameId3rd,
						tl.TranId3rd,
						4 AS TableID
					FROM dbo.translog AS tl WITH (NOLOCK)
						INNER JOIN @TmpShadow AS ts ON ts.CustId = tl.custid
					WHERE tl.winlostdate = @_Date
						AND tl.statusID IN (0, 1)
				END
			END
		END
		ELSE IF @_Date BETWEEN @BalanceUpDay AND @MoveBetsDay		-- bettrans14 range
		BEGIN
			IF @ViewSabaCoins = 0		-- View real player
			BEGIN
				INSERT INTO #Data (
					TransId, RefNo, CustId, Recommend, Currency, BetType, BetId, BetTeam, Hdp1, Hdp2,
					OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, WinLost, LicenseeWL, PlayerComm,
					Comm, Status, SecAcceptFlag, CheckTime, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip,
					BetFrom, MatchId, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
				)
				SELECT
					b14.transid,
					b14.refno,
					b14.custid,
					b14.recommend,
					b14.currency,
					b14.bettype,
					ISNULL(b14.betid, 0) AS BetId,
					b14.betteam,
					b14.hdp1,
					b14.hdp2,
					b14.oddsid,
					b14.oddstype,
					b14.odds,
					b14.modds,
					b14.oddsspread,
					b14.stake,
					b14.actual_stake,
					(b14.winlost - b14.actual_stake) AS WinLost,
					- (b14.winlost - b14.actual_stake) AS LicenseeWL,
					b14.playercomm,
					b14.comm,
					b14.status,
					b14.SecAcceptFlag,
					b14.checktime,
					b14.transdate,
					b14.winlostdate,
					b14.liveindicator,
					b14.livehomescore,
					b14.liveawayscore,
					b14.ip,
					b14.betfrom,
					b14.matchid,
					b14.betcheck,
					b14.comstatus,
					b14.transdesc,
					b14.betdaqid,
					b14.ExtraInfo,
					b14.WalletType,
					ISNULL(b14.RefCode, 0) AS RefCode,
					2 AS TableID
				FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b14.bettype
				WHERE b14.custid = @CustId
					AND b14.winlostdate = @_Date
					AND 1 = CASE
								WHEN @TransType = 0 THEN 1
								WHEN @TransType = 1 AND b14.statusID IN (111, 112, 113) THEN 1
								WHEN @TransType = 2 AND b14.statusID IN (101, 102, 103) THEN 1
								ELSE 0
							END
			END
			ELSE				-- View Saba Coins
			BEGIN
				INSERT INTO #Data (
					TransId, RefNo, CustId, Recommend, Currency, BetType, BetId, BetTeam, Hdp1, Hdp2,
					OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, WinLost, LicenseeWL, PlayerComm,
					Comm, Status, SecAcceptFlag, CheckTime, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip,
					BetFrom, MatchId, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
				)
				SELECT
					b14.transid,
					b14.refno,
					b14.custid,
					b14.recommend,
					b14.currency,
					b14.bettype,
					ISNULL(b14.betid, 0) AS BetId,
					b14.betteam,
					b14.hdp1,
					b14.hdp2,
					b14.oddsid,
					b14.oddstype,
					b14.odds,
					b14.modds,
					b14.oddsspread,
					b14.stake,
					b14.actual_stake,
					(b14.winlost - b14.actual_stake) AS WinLost,
					CASE
						WHEN s.ProductID = 1 AND b14.tpositiontaking = 0 THEN 0
						ELSE - (b14.winlost - b14.actual_stake)
					END AS LicenseeWL,
					b14.playercomm,
					b14.comm,
					b14.status,
					b14.SecAcceptFlag,
					b14.checktime,
					b14.transdate,
					b14.winlostdate,
					b14.liveindicator,
					b14.livehomescore,
					b14.liveawayscore,
					b14.ip,
					b14.betfrom,
					b14.matchid,
					b14.betcheck,
					b14.comstatus,
					b14.transdesc,
					b14.betdaqid,
					b14.ExtraInfo,
					b14.WalletType,
					ISNULL(b14.RefCode, 0) AS RefCode,
					2 AS TableID
				FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b14.bettype
					INNER JOIN @TmpShadow AS ts ON ts.CustId = b14.custid
				WHERE b14.winlostdate = @_Date
					AND 1 = CASE
								WHEN @TransType = 0 THEN 1
								WHEN @TransType = 1 AND b14.statusID IN (111, 112, 113) THEN 1
								WHEN @TransType = 2 AND b14.statusID IN (101, 102, 103) THEN 1
								ELSE 0
							END
			END
		END
		ELSE IF @_Date < @BalanceUpDay		-- bettrans_bk range
		BEGIN
			IF @ViewSabaCoins = 0		-- View real player
			BEGIN
				INSERT INTO #Data (
					TransId, RefNo, CustId, Recommend, Currency, BetType, BetId, BetTeam, Hdp1, Hdp2,
					OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, WinLost, LicenseeWL, PlayerComm,
					Comm, Status, SecAcceptFlag, CheckTime, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip,
					BetFrom, MatchId, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
				)
				SELECT
					bk.transid,
					bk.refno,
					bk.custid,
					bk.recommend,
					bk.currency,
					bk.bettype,
					ISNULL(bk.betid, 0) AS BetId,
					bk.betteam,
					bk.hdp1,
					bk.hdp2,
					bk.oddsid,
					bk.oddstype,
					bk.odds,
					bk.modds,
					bk.oddsspread,
					bk.stake,
					bk.actual_stake,
					(bk.winlost - bk.actual_stake) AS WinLost,
					- (bk.winlost - bk.actual_stake) AS LicenseeWL,
					bk.playercomm,
					bk.comm,
					bk.status,
					bk.SecAcceptFlag,
					bk.checktime,
					bk.transdate,
					bk.winlostdate,
					bk.liveindicator,
					bk.livehomescore,
					bk.liveawayscore,
					dp.IP,
					bk.betfrom,
					bk.matchid,
					bk.betcheck,
					bk.comstatus,
					bk.transdesc,
					bk.betdaqid,
					bk.ExtraInfo,
					bk.WalletType,
					ISNULL(bk.RefCode, 0) AS RefCode,
					3 AS TableID
				FROM bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK, INDEX = IX_custid)
					INNER JOIN @SportBettype AS s ON s.Bettype = bk.bettype
					CROSS APPLY dbo.f_IP_Decompress(bk.ip) AS dp
				WHERE bk.custid = @CustId
					AND bk.winlostdate = @_Date
					AND 1 = CASE
								WHEN @TransType = 0 THEN 1
								WHEN @TransType = 1 AND bk.statusID IN (111, 112, 113) THEN 1
								WHEN @TransType = 2 AND bk.statusID IN (101, 102, 103) THEN 1
								ELSE 0
							END
			END
			ELSE				-- View Saba Coins
			BEGIN
				INSERT INTO #Data (
					TransId, RefNo, CustId, Recommend, Currency, BetType, BetId, BetTeam, Hdp1, Hdp2,
					OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, WinLost, LicenseeWL, PlayerComm,
					Comm, Status, SecAcceptFlag, CheckTime, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip,
					BetFrom, MatchId, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
				)
				SELECT
					bk.transid,
					bk.refno,
					bk.custid,
					bk.recommend,
					bk.currency,
					bk.bettype,
					ISNULL(bk.betid, 0) AS BetId,
					bk.betteam,
					bk.hdp1,
					bk.hdp2,
					bk.oddsid,
					bk.oddstype,
					bk.odds,
					bk.modds,
					bk.oddsspread,
					bk.stake,
					bk.actual_stake,
					(bk.winlost - bk.actual_stake) AS WinLost,
					CASE
						WHEN s.ProductID = 1 AND bk.tpositiontaking = 0 THEN 0
						ELSE - (bk.winlost - bk.actual_stake)
					END AS LicenseeWL,
					bk.playercomm,
					bk.comm,
					bk.status,
					bk.SecAcceptFlag,
					bk.checktime,
					bk.transdate,
					bk.winlostdate,
					bk.liveindicator,
					bk.livehomescore,
					bk.liveawayscore,
					dp.IP,
					bk.betfrom,
					bk.matchid,
					bk.betcheck,
					bk.comstatus,
					bk.transdesc,
					bk.betdaqid,
					bk.ExtraInfo,
					bk.WalletType,
					ISNULL(bk.RefCode, 0) AS RefCode,
					3 AS TableID
				FROM bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK, INDEX = IX_custid)
					INNER JOIN @SportBettype AS s ON s.Bettype = bk.bettype
					INNER JOIN @TmpShadow AS ts ON ts.CustId = bk.custid
					CROSS APPLY dbo.f_IP_Decompress(bk.ip) AS dp
				WHERE bk.winlostdate = @_Date
					AND 1 = CASE
								WHEN @TransType = 0 THEN 1
								WHEN @TransType = 1 AND bk.statusID IN (111, 112, 113) THEN 1
								WHEN @TransType = 2 AND bk.statusID IN (101, 102, 103) THEN 1
								ELSE 0
							END
			END

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
					b.Stake = cob.stake
				FROM #Data AS b
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN #Data AS cb
						ON cb.RefNo = b.RefNo
						AND cb.BetType = 913
						AND cb.custid = @CustId
						AND cb.winlostdate = b.WinLostDate
				WHERE b.BetType = 912
			END
		END

		IF EXISTS (SELECT 1 FROM #Data)
		BEGIN
			-- Get Sport/Bettype info
			UPDATE b
			SET
				Product = CASE
							WHEN s.ProductID = 6 THEN 'OneRNG'							-- RNG Casino
							WHEN s.ProductID = 8 THEN 'Keno'
							WHEN s.ProductID = 21 THEN 'AllBet'
							WHEN s.ProductID = 22 THEN 'VB'								-- Macau Games
							WHEN s.ProductID = 25 THEN 'CO'								-- Cash Out
							WHEN s.ProductID = 28 THEN 'Lottery'
							WHEN s.ProductID = 32 THEN 'PP'								-- Pragmatic Play Casino
							WHEN s.ProductID = 34 THEN 'CC'								-- Card Club
							WHEN s.ProductID = 36 THEN 'SG'								-- Spadegaming
							WHEN s.ProductID = 37 THEN 'NPHP'							-- Non-peak Hour Promotion
							WHEN s.ProductID = 38 THEN 'VRG'							-- Virtual Games
							WHEN s.ProductID = 39 THEN 'SAG'							-- SA Gaming
							WHEN s.ProductID = 40 THEN 'TG'								-- Table Games
							WHEN s.ProductID = 42 THEN 'SBC'							-- Saba.club
							WHEN s.ProductID = 43 THEN 'I4D'							-- Indo 4D
							WHEN s.ProductID = 45 THEN 'SXG'							-- Sexy Gaming
							WHEN s.ProductID = 49 THEN 'VS3'							-- Virtual Sports 3 (Old)
							WHEN s.ProductID = 51 THEN 'WM'								-- WM Live Casino
							WHEN s.ProductID = 55 THEN 'PGS'							-- PG Soft
							WHEN s.ProductID = 56 THEN 'JK'								-- Joker
							WHEN s.ProductID = 57 THEN 'BG'								-- Big Gaming
							WHEN s.ProductID = 60 THEN 'MXG'							-- MaxGame
							WHEN s.ProductID = 61 THEN 'HB'								-- Habanero
							WHEN s.ProductID = 62 THEN 'CG'								-- CG
							WHEN s.ProductID = 63 THEN 'SLT'							-- Sports Lottery
							WHEN s.ProductID = 66 THEN 'VGA'							-- Vgaming
							WHEN s.ProductID = 67 THEN 'AP'								-- AdvantPlay
							WHEN s.ProductID = 68 THEN 'APM'							-- AdvantPlay Mini
							WHEN s.ProductID = 69 THEN 'BTC'							-- Bitcoin
							WHEN s.ProductID = 70 THEN 'FGGL'							-- FGG
							WHEN s.ProductId = 72 THEN 'SEA'							-- SEAL Entertainment
							WHEN s.ProductID = 73 THEN 'MGRNG'							-- MG-RNG
							WHEN s.ProductID = 74 THEN 'TIP'							-- Player Tips
							WHEN s.ProductID = 75 THEN 'JIG'							-- Jili
							WHEN s.ProductID = 76 THEN 'YB'								-- YeeBet
							WHEN s.ProductID = 77 THEN 'LG'								-- Virtual Sports 3
							WHEN s.ProductID = 100 THEN 'PTRNG'							-- Playtech RNG
							WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
							WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'		-- Happy 5 Linked Games (Number Game)
							WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
							WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
							WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
							WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
							ELSE 'Unknown'
						END,
				RefTable = s.RefTable,
				EventType = s.EventType,
				SubProduct = s.SubProduct
			FROM #Data AS b
				INNER JOIN @SportBettype AS s ON b.BetType = s.BetType

			DELETE b
			FROM #Data AS b
			WHERE (@ViewSabaCoins = 0
					AND NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency))
				OR BetType IN (903, 913)

			IF EXISTS (SELECT 1 FROM #Data)
			BEGIN
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
						PlayerComm		MONEY,
						Comm			MONEY
					)

					-- Prepare temp table
					INSERT INTO @RefCodeTmp
					(
						RefCode,
						TransId,
						Stake,
						Actual_Stake,
						WinLost,
						LicenseeWL,
						PlayerComm,
						Comm
					)
					SELECT
						RefCode,
						MIN(TransId) AS TransId,
						SUM(Stake) AS Stake,
						SUM(Actual_Stake) AS Actual_Stake,
						SUM(WinLost) AS WinLost,
						SUM(LicenseeWL) AS LicenseeWL,
						SUM(PlayerComm) AS PlayerComm,
						SUM(Comm) AS Comm
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
							b.PlayerComm = r.PlayerComm,
							b.Comm = r.Comm,
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

				-- Get yesterday and today running and settled bettransRnG/bettransLC tickets
				IF @_Date >= @Yesterday
				BEGIN
					-- bettransRnG
					IF EXISTS (SELECT 1 FROM #Data WHERE RefTable = 1)
					BEGIN
						IF @TransType = 1		-- Settled
						BEGIN
							INSERT INTO @TmpData
							(
								RefNo,
								Odds,
								Stake,
								Actual_Stake,
								Status,
								WinLost,
								LicenseeWL,
								PlayerComm,
								Comm,
								OddsSpread
							)
							SELECT
								c.TransId AS RefNo,
								CASE
									WHEN Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG', 'PTRNG') THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
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
								- SUM(brng.winlost - brng.actual_stake) AS LicenseeWL,
								SUM(brng.playercomm) AS Commission,
								SUM(brng.comm) AS Comm,
								CASE
									WHEN c.Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG', 'PTRNG') THEN ISNULL(SUM(brng.BetStake), 0)
									ELSE 0
								END AS OddsSpread
							FROM #Data AS c
								INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
							WHERE c.RefTable = 1 AND brng.statusID NOT IN (0, 1)
							GROUP BY
								c.TransId,
								c.Product
						END
						ELSE IF @TransType = 3		-- Running
						BEGIN
							INSERT INTO @TmpData
							(
								RefNo,
								Odds,
								Stake,
								Actual_Stake,
								Status,
								WinLost,
								LicenseeWL,
								PlayerComm,
								Comm,
								OddsSpread
							)
							SELECT
								c.TransId AS RefNo,
								0 AS Odds,
								SUM(brng.stake) AS Stake,
								SUM(brng.actual_stake) AS Actual_Stake,
								'Running' AS Status,
								0 AS WinLost,
								0 AS LicenseeWL,
								0 AS PlayerComm,
								0 AS Comm,
								0 AS OddsSpread
							FROM #Data AS c
								INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
							WHERE c.RefTable = 1 AND brng.statusID IN (0, 1)
							GROUP BY
								c.TransId,
								c.Product
						END
					END

					-- bettransLC
					IF EXISTS (SELECT 1 FROM #Data WHERE RefTable = 2)
					BEGIN
						IF @TransType = 1		-- Settled
						BEGIN
							INSERT INTO @TmpData
							(
								RefNo,
								Odds,
								Stake,
								Actual_Stake,
								Status,
								WinLost,
								LicenseeWL,
								PlayerComm,
								Comm,
								OddsSpread
							)
							SELECT
								c.TransId AS RefNo,
								CASE
									WHEN c.SubProduct LIKE '%Jackpot%' THEN ISNULL(AVG(CASE WHEN blc.statusID IN (111, 112, 113) THEN blc.ContributionRate END), 0)
									ELSE 0
								END AS Odds,
								SUM(blc.stake) AS Stake,
								SUM(blc.actual_stake) AS Actual_Stake,
								CASE
									WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
									WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
									ELSE 'Draw'
								END AS Status,
								SUM(blc.winlost - blc.actual_stake) AS WinLost,
								- SUM(blc.winlost - blc.actual_stake) AS LicenseeWL,
								SUM(blc.playercomm) AS Commission,
								SUM(blc.comm) AS Comm,
								CASE
									WHEN c.SubProduct LIKE '%Jackpot%' THEN ISNULL(SUM(blc.BetStake), 0)
									ELSE 0
								END AS OddsSpread
							FROM #Data AS c
								INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
							WHERE c.RefTable = 2 AND blc.statusID NOT IN (0, 1)
							GROUP BY
								c.TransId,
								c.Product,
								c.SubProduct
						END
						ELSE IF @TransType = 3		-- Running
						BEGIN
							INSERT INTO @TmpData
							(
								RefNo,
								Odds,
								Stake,
								Actual_Stake,
								Status,
								WinLost,
								LicenseeWL,
								PlayerComm,
								Comm,
								OddsSpread
							)
							SELECT
								c.TransId AS RefNo,
								0 AS Odds,
								SUM(blc.stake) AS Stake,
								SUM(blc.actual_stake) AS Actual_Stake,
								'Running' AS Status,
								0 AS WinLost,
								0 AS LicenseeWL,
								0 AS PlayerComm,
								0 AS Comm,
								0 AS OddsSpread
							FROM #Data AS c
								INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
							WHERE c.RefTable = 2 AND blc.statusID IN (0, 1)
							GROUP BY
								c.TransId,
								c.Product
						END
					END

					DELETE b
					FROM #Data AS b
					WHERE b.RefTable IN (1, 2)
						AND NOT EXISTS (SELECT 1 FROM @TmpData WHERE RefNo = b.TransId)
				END

				SELECT @Currency = currency
				FROM dbo.Customer WITH (NOLOCK)
				WHERE custid = @CustId

				DECLARE @ExDate SMALLDATETIME

				SET @ExDate = CASE
									WHEN @_Date > CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) THEN CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)
									ELSE @_Date
								END

				-- Get exchange rate
				IF @BaseCurrency <> ''
				BEGIN
					SELECT @Rate = e.Rate
					FROM dbo.Lrf_f_GetExchangeRate(@ExDate, @ExDate, @BaseCurrency, '') AS e
					WHERE e.ExchangeId = @Currency
				END

				-- Return data
				SELECT
					@TotalRows		= COUNT(b.TransId),
					@SumStake		= SUM(b.Stake		* ISNULL(@Rate, 1)),
					@SumWinlost		= SUM(b.WinLost		* ISNULL(@Rate, 1)),
					@SumLicenseeWL	= SUM(b.LicenseeWL	* ISNULL(@Rate, 1)),
					@SumComm		= SUM(b.Comm		* ISNULL(@Rate, 1)),
					@SumPlayerComm	= SUM(b.PlayerComm	* ISNULL(@Rate, 1))
				FROM #Data AS b

				DECLARE @SortText VARCHAR(100)

				-- Get sort text
				SET @SortText = CASE
									WHEN @SortType = 0 THEN 'TransDate'
									WHEN @SortType = 1 THEN 'Stake'
									WHEN @SortType = 2 THEN 'WinLost'
									WHEN @SortType = 3 THEN 'LicenseeWL'
									ELSE ''
								END

				IF @BaseCurrency <> '' AND @SortType IN (1, 2, 3)
				BEGIN
					SET @SortText = @SortText + ' * ISNULL(e.Rate, 1)'
				END

				SET @SortText = @SortText + ' ' + CASE
													WHEN @SortOrder = 1 THEN 'ASC'
													WHEN @SortOrder = 2 THEN 'DESC'
													ELSE ''
												END

				DECLARE @RowStart INT,
					@RowEnd INT

				SELECT @PageIndex = @PageIndex - 1,
					@RowStart = @PageSize * @PageIndex + 1,
					@RowEnd = @RowStart + @PageSize - 1

				DECLARE @Sql NVARCHAR(2000)

				SET @Sql = 
					N'SELECT a.*
					FROM
						(
							SELECT
								ROW_NUMBER() OVER (ORDER BY ' + @SortText + N') AS RowNum,
								d.*
							FROM #Data AS d
						) AS a
					WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
					ORDER BY a.RowNum ASC'

				INSERT INTO #PagingData
				(
					RowNum, TransId, RefNo, CustId, Recommend, Currency, SportType, BetType, BetId, BetTeam,
					Hdp1, Hdp2, OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, WinLost,
					LicenseeWL, PlayerComm, Comm, Status, SettlementStatus, SecAcceptFlag, CheckTime, TransDate, WinLostDate, LiveIndicator,
					LiveHomeScore, LiveAwayScore, Ip, BetFrom, LeagueId, LeagueGroupId, MatchId, MatchCode, Race, EventDate,
					HomeId, AwayId, BetStatus, IsNeutral, ShowTime, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo,
					OriginalStake, OriginalBetType, WalletType, RefCode, SiteId, ProductId, EventId, Custom1, Custom2, Custom3,
					Gameid3rd, Tranid3rd, TableID, Product, SubProduct, RefTable, EventType
				)
				EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

				-- bettrans range
				IF @_Date > @MoveBetsDay
				BEGIN
					UPDATE p
					SET
						TransId = CASE
									WHEN p.Product = 'Parlay' AND p.bettype = 29 AND ISNULL(p.betid, 0) > 0 THEN p.betid
									ELSE p.transid
								END,
						SportType = CASE
										WHEN p.Product IN ('OneRNG', 'CC', 'SG', 'NPHP', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK', 'H5LG', 'SLT', 
											'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'TIP', 'JIG', 'YB', 'MGRNG', 'SEA') THEN p.matchid		-- ONERnG, Card Club, NPH Promotion
										WHEN p.Product = 'Keno' THEN 202	-- Keno
										WHEN p.Product = 'Lottery' THEN 220	-- Lottery
										WHEN p.Product = 'AllBet' THEN 211	-- AllBet
										WHEN p.Product = 'VB' THEN 212		-- Macau Games
										WHEN p.Product = 'PP' THEN 248		-- Pragmatic Casino
										WHEN p.Product IN ('Outright') THEN l.sporttype
										WHEN p.EventType = 1 THEN m.sporttype
										WHEN p.EventType = 3 THEN vr.SportType
										WHEN p.EventType = 5 THEN m3rd.SportType
										WHEN p.RefTable IN (1, 2) THEN p.MatchId
										ELSE p.MatchId
									END,
						Odds = CASE
									WHEN p.Product IN ('VB', 'PP', 'OneRNG', 'Allbet', 'SBC', 'VGA', 'SG', 'PTRNG') AND x.Odds IS NOT NULL THEN x.Odds
									WHEN p.SubProduct LIKE '%Jackpot%' AND x.Odds IS NOT NULL THEN x.Odds
									ELSE p.odds
								END,
						Stake = CASE
									WHEN p.RefTable IN (1, 2) AND x.Stake IS NOT NULL THEN x.Stake
									ELSE p.stake
								END,
						Actual_Stake = CASE
										WHEN p.RefTable IN (1, 2) AND x.Actual_Stake IS NOT NULL THEN x.Actual_Stake
										ELSE p.actual_stake
									END,
						Status = CASE
									WHEN p.RefTable IN (1, 2) AND x.Status IS NOT NULL THEN x.Status
									WHEN p.Product = 'SB' AND p.bettype NOT IN (9, 29)
										AND p.status = 'running' AND ISNULL(p.SecAcceptFlag, 0) = 1 AND ISNULL(p.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
									WHEN p.bettype IN (9, 29, 2799) AND p.status = 'running' THEN
										CASE
											WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
														WHERE bm.custid = p.custid
															AND bm.refno = p.refno
															AND (bm.status = 'waiting'
																OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
												THEN 'Waiting'
											ELSE p.status
										END
									WHEN p.Product = 'TG' AND p.status = 'Won' AND p.modds = 0.25 THEN 'Half Won'
									WHEN p.Product = 'TG' AND p.status = 'Lose' AND p.modds = -0.25 THEN 'Half Lose'
									ELSE p.status
								END,
						SettlementStatus = CASE
												WHEN p.Product = 'SB' THEN ISNULL(m.SettlementStatus, 0)
												ELSE 0
											END,
						WinLost = CASE
										WHEN p.RefTable IN (1, 2) AND x.WinLost IS NOT NULL THEN x.WinLost
										ELSE p.WinLost
									END,
						LicenseeWL = CASE
										WHEN p.RefTable IN (1, 2) AND x.LicenseeWL IS NOT NULL THEN x.LicenseeWL
										ELSE p.LicenseeWL
									END,
						PlayerComm = CASE
										WHEN p.RefTable IN (1, 2) AND x.PlayerComm IS NOT NULL THEN x.PlayerComm
										ELSE p.PlayerComm
									END,
						Comm = CASE
										WHEN p.RefTable IN (1, 2) AND x.Comm IS NOT NULL THEN x.Comm
										ELSE p.Comm
									END,
						LeagueId = CASE
										WHEN p.EventType = 1 THEN m.leagueid
										WHEN p.EventType = 5 THEN m3rd.League3rdId
										WHEN p.Product IN ('Outright') THEN o.leagueid
										WHEN p.EventType = 3 THEN vr.LeagueID
										ELSE 0
									END,
						LeagueGroupId = CASE
											WHEN p.Product IN ('SB') THEN le.LeagueGroupID
											ELSE 0
										END,
						MatchId = CASE
										WHEN p.Product IN ('TIP') THEN ISNULL(CAST(('<xml>' + p.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
										ELSE p.matchid
									END,
						MatchCode = CASE
										WHEN p.EventType = 1 THEN m.matchcode
										WHEN p.Product IN ('Outright') THEN o.matchcode
										ELSE ''
									END,
						Race = CASE
									WHEN p.Product IN ('Outright') THEN o.groupmatch
									ELSE ''
								END,
						EventDate = CASE
										WHEN p.Product IN ('SB', 'CO') THEN m.GlobalShowTime
										WHEN p.Product IN ('BTC') THEN m3rd.EndTime
										WHEN p.Product IN ('Outright') THEN o.eventdate
										WHEN p.EventType = 1 THEN m.eventdate
										ELSE p.winlostdate
									END,
						HomeId = CASE
									WHEN p.EventType = 1 THEN m.homeid
									WHEN p.EventType = 5 THEN m3rd.HomeId
									WHEN p.Product IN ('Outright') THEN o.teamid
									ELSE 0
								END,
						AwayId = CASE
									WHEN p.EventType = 1 THEN m.awayid
									WHEN p.EventType = 5 THEN m3rd.AwayId
									ELSE 0
								END,
						BetStatus = CASE
										WHEN p.EventType = 1 THEN m.betstatus
										ELSE ''
									END,
						IsNeutral = CASE
										WHEN p.EventType = 1 THEN ISNULL(m.IsNeutral, 0)
										ELSE 0
									END,
						ShowTime = CASE
										WHEN p.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
										WHEN p.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
										WHEN p.Product IN ('SB', 'CO', 'NG') THEN ISNULL(m.showtime, '')
										ELSE ''
									END,
						BetCheck = CASE
										WHEN p.Product IN ('SB', 'CO', 'VRG', 'SLT', 'H5LG') THEN ISNULL(p.betcheck, '')
										WHEN p.Product IN ('Keno') THEN ISNULL(p.comstatus, '')
										WHEN p.EventType = 0 AND p.RefTable = 0 THEN ISNULL(p.betcheck, '')
										ELSE ''
									END,
						ComStatus = CASE WHEN p.comstatus = '1' THEN '1' ELSE '0' END,
						TransDesc = CASE
										WHEN p.Product IN ('OneRNG', 'CC', 'SG', 'Keno', 'VB', 'Lottery', 'PP', 
											'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(p.transdesc, '')
										WHEN p.Product = 'Parlay' AND p.OddsSpread = 3 THEN ISNULL(p.transdesc, '')
										WHEN p.EventType IN (1, 3, 5) THEN ISNULL(p.transdesc, '')
										ELSE ''
									END,
						OddsSpread = CASE
										WHEN p.Product IN ('PP', 'SBC', 'VGA', 'SG', 'PTRNG') AND x.OddsSpread IS NOT NULL THEN x.OddsSpread
										WHEN p.SubProduct LIKE '%Jackpot%' AND x.OddsSpread IS NOT NULL THEN x.OddsSpread
										ELSE ISNULL(p.oddsspread, 0)
									END,
						BetdaqId = CASE
									WHEN p.Product IN ('SB', 'CO') THEN ISNULL(p.betdaqid, -1)
									ELSE -1
								END,
						OriginalStake = 0,
						OriginalBetType = CASE
												WHEN p.Product IN ('SB') AND p.stake <> 0 THEN -1
												WHEN p.Product IN ('CO') THEN p.OriginalBetType
												ELSE 0
											END,
						WalletType = CASE
										WHEN p.Product IN ('SB') THEN ISNULL(p.WalletType, 0)
										ELSE 0
									END,
						RefCode = CASE
										WHEN p.Product IN ('SB') THEN ISNULL(p.RefCode, 0)
										ELSE 0
									END,
						SiteId = CASE
									WHEN p.Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), p.BetdaqId)
									ELSE ''
								END
					FROM #PagingData AS p
						LEFT JOIN dbo.match AS m WITH (NOLOCK) ON p.EventType = 1 AND p.matchid = m.matchid
						LEFT JOIN dbo.League AS le WITH (NOLOCK) ON p.Product IN ('SB') AND le.leagueid = m.leagueid
						LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON p.EventType = 5 AND m3rd.Match3rdId = p.matchid
						LEFT JOIN @TmpData AS x
							ON p.RefTable IN (1, 2)
							AND p.Winlostdate >= @Yesterday
							AND x.RefNo = p.transid
						LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON p.Product IN ('Outright') AND p.matchid = o.orid
						LEFT JOIN dbo.League AS l WITH (NOLOCK) ON p.Product IN ('Outright') AND o.leagueid = l.leagueid
						LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON p.EventType = 3 AND vr.EventID = p.matchid
					WHERE p.TableID = 1

					-- translog
					UPDATE p
					SET SportType = CASE
										WHEN p.Product = 'Keno' THEN 202
										WHEN p.Product = 'Lottery' THEN 220		-- Lottery
										WHEN p.Product IN ('VRG', 'TG', 'I4D', 'H5LG', 'SLT', 'VS3') THEN p.productID	-- Virtual Games, Table Games
										ELSE 0
									END,
						BetId = 0,
						BetTeam = '',
						Hdp1 = 0,
						Hdp2 = 0,
						OddsType = 0,
						OddsId = 0,
						MOdds = 0,
						SettlementStatus = 0,
						WinLost = 0,
						PlayerComm = 0,
						LiveIndicator = 0,
						LiveHomeScore = 0,
						LiveAwayScore = 0,
						LeagueId = 0,
						MatchId = 0,
						MatchCode = '',
						Race = '',
						EventDate = p.winlostdate,
						HomeId = 0,
						AwayId = 0,
						IsNeutral = 0,
						ShowTime = '',
						BetCheck = CASE
										WHEN p.Product IN ('Keno') THEN ISNULL(p.Custom2, '')
										WHEN p.Product IN ('VRG', 'SLT') THEN p.TranId3rd
										WHEN p.Product IN ('H5LG') THEN p.Gameid3rd
										WHEN p.Product IN ('VS3') THEN ISNULL(p.Custom1, '')
										ELSE ''
									END,
						ComStatus = 0,
						OddsSpread = 0,
						BetdaqId = -1,
						ExtraInfo = ''
					FROM #PagingData AS p
					WHERE TableID = 4

					-- Get ticket detail
					-- Virtual Sports Racing
					INSERT INTO @DetailData
					(
						RefNo,
						Odds,
						Stake,
						Status,
						APositionTaking,
						BetType,
						BetTeam
					)
					SELECT
						bm.refno,
						bm.odds,
						bm.stake,
						bm.status,
						bm.apositiontaking,
						bm.bettype,
						bm.betteam
					FROM #PagingData AS c
						INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON c.RefNo = bm.refno
					WHERE c.Product = 'VR' AND bm.custid = @CustId
				END
				ELSE IF @_Date BETWEEN @BalanceUpDay AND @MoveBetsDay		-- bettrans14 range
				BEGIN
					UPDATE p14
					SET
						TransId = CASE
									WHEN p14.Product = 'Parlay' AND p14.bettype = 29 AND ISNULL(p14.betid, 0) > 0 THEN p14.betid
									ELSE p14.transid
								END,
						SportType = CASE
										WHEN p14.Product IN ('OneRNG', 'CC', 'SG', 'NPHP', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK', 'H5LG', 'SLT', 
											'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'TIP', 'JIG', 'YB', 'MGRNG', 'SEA') THEN p14.matchid		-- ONERnG, Card Club, NPH Promotion
										WHEN p14.Product = 'Keno' THEN 202	-- Keno
										WHEN p14.Product = 'Lottery' THEN 220	-- Lottery
										WHEN p14.Product = 'AllBet' THEN 211	-- AllBet
										WHEN p14.Product = 'VB' THEN 212		-- Macau Games
										WHEN p14.Product = 'PP' THEN 248		-- Pragmatic Casino
										WHEN p14.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.sporttype
										WHEN p14.Product IN ('Outright') THEN l.sporttype
										WHEN p14.EventType = 1 THEN m.sporttype
										WHEN p14.EventType = 3 THEN vr.SportType
										WHEN p14.EventType = 5 THEN m3rd.SportType
										WHEN p14.RefTable IN (1, 2) THEN p14.MatchId
										ELSE p14.MatchId
									END,
						Status = CASE
									WHEN p14.Product = 'TG' AND p14.status = 'Won' AND p14.modds = 0.25 THEN 'Half Won'
									WHEN p14.Product = 'TG' AND p14.status = 'Lose' AND p14.modds = -0.25 THEN 'Half Lose'
									ELSE p14.status
								END,
						SettlementStatus = 0,
						LeagueId = CASE
										WHEN p14.EventType = 1 THEN m.leagueid
										WHEN p14.EventType = 5 THEN m3rd.League3rdId
										WHEN p14.Product IN ('Outright') THEN o.leagueid
										WHEN p14.EventType = 3 THEN vr.LeagueID
										ELSE 0
									END,
						LeagueGroupId = CASE
											WHEN p14.Product IN ('SB') THEN le.LeagueGroupID
											ELSE 0
										END,
						MatchId = CASE
										WHEN p14.Product IN ('TIP') THEN ISNULL(CAST(('<xml>' + p14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
										ELSE p14.matchid
									END,
						MatchCode = CASE
										WHEN p14.EventType = 1 THEN m.matchcode
										WHEN p14.Product IN ('Outright') THEN o.matchcode
										ELSE ''
									END,
						Race = CASE
									WHEN p14.Product IN ('Outright') THEN o.groupmatch
									ELSE ''
								END,
						EventDate = CASE
										WHEN p14.Product IN ('SB', 'CO') THEN m.GlobalShowTime
										WHEN p14.Product IN ('BTC') THEN m3rd.EndTime
										WHEN p14.Product IN ('Outright') THEN o.eventdate
										WHEN p14.EventType = 1 THEN m.eventdate
										ELSE p14.winlostdate
									END,
						HomeId = CASE
									WHEN p14.EventType = 1 THEN m.homeid
									WHEN p14.EventType = 5 THEN m3rd.HomeId
									WHEN p14.Product IN ('Outright') THEN o.teamid
									ELSE 0
								END,
						AwayId = CASE
									WHEN p14.EventType = 1 THEN m.awayid
									WHEN p14.EventType = 5 THEN m3rd.AwayId
									ELSE 0
								END,
						BetStatus = CASE
										WHEN p14.EventType = 1 THEN m.betstatus
										ELSE ''
									END,
						IsNeutral = CASE
										WHEN p14.EventType = 1 THEN ISNULL(m.IsNeutral, 0)
										ELSE 0
									END,
						ShowTime = CASE
										WHEN p14.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
										WHEN p14.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
										WHEN p14.Product IN ('SB', 'CO', 'NG') THEN ISNULL(m.showtime, '')
										ELSE ''
									END,
						BetCheck = CASE
										WHEN p14.Product IN ('SB', 'CO', 'VRG', 'SLT', 'H5LG') THEN ISNULL(p14.betcheck, '')
										WHEN p14.Product IN ('Keno') THEN ISNULL(p14.comstatus, '')
										WHEN p14.EventType = 0 AND p14.RefTable = 0 THEN ISNULL(p14.betcheck, '')
										ELSE ''
									END,
						ComStatus = CASE WHEN p14.comstatus = '1' THEN '1' ELSE '0' END,
						TransDesc = CASE
										WHEN p14.Product IN ('OneRNG', 'CC', 'SG', 'Keno', 'VB', 'Lottery', 'PP', 
											'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(p14.transdesc, '')
										WHEN p14.Product = 'Parlay' AND p14.OddsSpread = 3 THEN ISNULL(p14.transdesc, '')
										WHEN p14.EventType IN (1, 3, 5) THEN ISNULL(p14.transdesc, '')
										ELSE ''
									END,
						BetdaqId = CASE
									WHEN p14.Product IN ('SB', 'CO') THEN ISNULL(p14.betdaqid, -1)
									ELSE -1
								END,
						OriginalStake = 0,
						OriginalBetType = CASE
												WHEN p14.Product IN ('SB') AND p14.stake <> 0 THEN -1
												WHEN p14.Product IN ('CO') THEN p14.OriginalBetType
												ELSE 0
											END,
						WalletType = CASE
										WHEN p14.Product IN ('SB') THEN ISNULL(p14.WalletType, 0)
										ELSE 0
									END,
						RefCode = CASE
										WHEN p14.Product IN ('SB') THEN ISNULL(p14.RefCode, 0)
										ELSE 0
									END,
						SiteId = CASE
									WHEN p14.Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), p14.BetdaqId)
									ELSE ''
								END
					FROM #PagingData AS p14
						LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON p14.EventType = 1 AND p14.matchid = m.matchid
						LEFT JOIN dbo.League AS le WITH (NOLOCK) ON p14.Product IN ('SB') AND le.leagueid = m.leagueid
						LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON p14.EventType = 5 AND m3rd.Match3rdId = p14.matchid
						LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON p14.Product IN ('Outright') AND p14.matchid = o.orid
						LEFT JOIN dbo.League AS l WITH (NOLOCK) ON p14.Product IN ('Outright') AND o.leagueid = l.leagueid
						LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON p14.EventType = 3 AND vr.EventID = p14.matchid
					WHERE p14.TableID = 2

					-- Get ticket detail
					-- Virtual Sports Racing
					INSERT INTO @DetailData
					(
						RefNo,
						Odds,
						Stake,
						Status,
						APositionTaking,
						BetType,
						BetTeam
					)
					SELECT
						bm.refno,
						bm.odds,
						bm.stake,
						bm.status,
						bm.apositiontaking,
						bm.bettype,
						bm.betteam
					FROM #PagingData AS c
						INNER JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON c.RefNo = bm.refno
					WHERE c.Product = 'VR' AND bm.custid = @CustId
				END
				ELSE IF @_Date < @BalanceUpDay		-- bettrans_bk range
				BEGIN
					UPDATE pbk
					SET
						TransId = CASE
									WHEN pbk.Product = 'Parlay' AND pbk.bettype = 29 AND ISNULL(pbk.betid, 0) > 0 THEN pbk.betid
									ELSE pbk.transid
								END,
						SportType = CASE
										WHEN pbk.Product IN ('OneRNG', 'CC', 'SG', 'NPHP', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK', 'H5LG', 'SLT', 
											'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'TIP', 'JIG', 'YB', 'MGRNG', 'SEA') THEN pbk.matchid		-- ONERnG, Card Club, NPH Promotion
										WHEN pbk.Product = 'Keno' THEN 202	-- Keno
										WHEN pbk.Product = 'Lottery' THEN 220	-- Lottery
										WHEN pbk.Product = 'AllBet' THEN 211	-- AllBet
										WHEN pbk.Product = 'VB' THEN 212		-- Macau Games
										WHEN pbk.Product = 'PP' THEN 248		-- Pragmatic Casino
										WHEN pbk.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.sporttype
										WHEN pbk.Product IN ('Outright') THEN l.sporttype
										WHEN pbk.EventType = 1 THEN m.sporttype
										WHEN pbk.EventType = 3 THEN vr.SportType
										WHEN pbk.EventType = 5 THEN m3rd.SportType
										WHEN pbk.RefTable IN (1, 2) THEN pbk.MatchId
										ELSE pbk.MatchId
									END,
						Status = CASE
									WHEN pbk.Product = 'TG' AND pbk.status = 'Won' AND pbk.modds = 0.25 THEN 'Half Won'
									WHEN pbk.Product = 'TG' AND pbk.status = 'Lose' AND pbk.modds = -0.25 THEN 'Half Lose'
									ELSE pbk.status
								END,
						SettlementStatus = 0,
						LeagueId = CASE
										WHEN pbk.EventType = 1 THEN m.leagueid
										WHEN pbk.EventType = 5 THEN m3rd.League3rdId
										WHEN pbk.Product IN ('Outright') THEN o.leagueid
										WHEN pbk.EventType = 3 THEN vr.LeagueID
										ELSE 0
									END,
						LeagueGroupId = CASE
											WHEN pbk.Product IN ('SB') THEN le.LeagueGroupID
											ELSE 0
										END,
						MatchId = CASE
										WHEN pbk.Product IN ('TIP') THEN ISNULL(CAST(('<xml>' + pbk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
										ELSE pbk.matchid
									END,
						MatchCode = CASE
										WHEN pbk.EventType = 1 THEN m.matchcode
										WHEN pbk.Product IN ('Outright') THEN o.matchcode
										ELSE ''
									END,
						Race = CASE
									WHEN pbk.Product IN ('Outright') THEN o.groupmatch
									ELSE ''
								END,
						EventDate = CASE
										WHEN pbk.Product IN ('SB', 'CO') THEN m.GlobalShowTime
										WHEN pbk.Product IN ('BTC') THEN m3rd.EndTime
										WHEN pbk.Product IN ('Outright') THEN o.eventdate
										WHEN pbk.EventType = 1 THEN m.eventdate
										ELSE pbk.winlostdate
									END,
						HomeId = CASE
									WHEN pbk.EventType = 1 THEN m.homeid
									WHEN pbk.EventType = 5 THEN m3rd.HomeId
									WHEN pbk.Product IN ('Outright') THEN o.teamid
									ELSE 0
								END,
						AwayId = CASE
									WHEN pbk.EventType = 1 THEN m.awayid
									WHEN pbk.EventType = 5 THEN m3rd.AwayId
									ELSE 0
								END,
						BetStatus = CASE
										WHEN pbk.EventType = 1 THEN m.betstatus
										ELSE ''
									END,
						IsNeutral = CASE
										WHEN pbk.EventType = 1 THEN ISNULL(m.IsNeutral, 0)
										ELSE 0
									END,
						ShowTime = CASE
										WHEN pbk.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
										WHEN pbk.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
										WHEN pbk.Product IN ('SB', 'CO', 'NG') THEN ISNULL(m.showtime, '')
										ELSE ''
									END,
						BetCheck = CASE
										WHEN pbk.Product IN ('SB', 'CO', 'VRG', 'SLT', 'H5LG') THEN ISNULL(pbk.betcheck, '')
										WHEN pbk.Product IN ('Keno') THEN ISNULL(pbk.comstatus, '')
										WHEN pbk.EventType = 0 AND pbk.RefTable = 0 THEN ISNULL(pbk.betcheck, '')
										ELSE ''
									END,
						ComStatus = CASE WHEN pbk.comstatus = '1' THEN '1' ELSE '0' END,
						TransDesc = CASE
										WHEN pbk.Product IN ('OneRNG', 'CC', 'SG', 'Keno', 'VB', 'Lottery', 'PP', 
											'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(pbk.transdesc, '')
										WHEN pbk.Product = 'Parlay' AND pbk.OddsSpread = 3 THEN ISNULL(pbk.transdesc, '')
										WHEN pbk.EventType IN (1, 3, 5) THEN ISNULL(pbk.transdesc, '')
										ELSE ''
									END,
						BetdaqId = CASE
									WHEN pbk.Product IN ('SB', 'CO') THEN ISNULL(pbk.betdaqid, -1)
									ELSE -1
								END,
						OriginalStake = 0,
						OriginalBetType = CASE
												WHEN pbk.Product IN ('SB') AND pbk.stake <> 0 THEN -1
												WHEN pbk.Product IN ('CO') THEN pbk.OriginalBetType
												ELSE 0
											END,
						WalletType = CASE
										WHEN pbk.Product IN ('SB') THEN ISNULL(pbk.WalletType, 0)
										ELSE 0
									END,
						RefCode = CASE
										WHEN pbk.Product IN ('SB') THEN ISNULL(pbk.RefCode, 0)
										ELSE 0
									END,
						SiteId = CASE
									WHEN pbk.Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), pbk.BetdaqId)
									ELSE ''
								END
					FROM #PagingData AS pbk
						LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON pbk.EventType = 1 AND pbk.matchid = m.matchid
						LEFT JOIN dbo.League AS le WITH (NOLOCK) ON pbk.Product IN ('SB') AND le.leagueid = m.leagueid
						LEFT JOIN bodb_Archive.dbo.Match3rd_bk AS m3rd WITH (NOLOCK) ON pbk.EventType = 5 AND m3rd.Match3rdId = pbk.matchid
						LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON pbk.Product IN ('Outright') AND pbk.matchid = o.orid
						LEFT JOIN dbo.League AS l WITH (NOLOCK) ON pbk.Product IN ('Outright') AND o.leagueid = l.leagueid
						LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON pbk.EventType = 3 AND vr.EventID = pbk.matchid
					WHERE pbk.TableID = 3

					-- Get ticket detail
					-- Virtual Sports Racing
					INSERT INTO @DetailData
					(
						RefNo,
						Odds,
						Stake,
						Status,
						APositionTaking,
						BetType,
						BetTeam
					)
					SELECT
						bm.refno,
						bm.odds,
						bm.stake,
						bm.status,
						bm.apositiontaking,
						bm.bettype,
						bm.betteam
					FROM #PagingData AS c
						INNER JOIN bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK) ON c.RefNo = bm.refno
					WHERE c.Product = 'VR' AND bm.custid = @CustId
				END

				-- Get match info for Player Tips
				IF EXISTS (	SELECT 1
							FROM #PagingData AS b
								INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
							WHERE b.Product = 'TIP')
				BEGIN
					UPDATE b
					SET
						LeagueId = m.leagueid,
						HomeId = m.homeid,
						AwayId = m.awayid,
						EventDate = m.GlobalShowTime
					FROM #PagingData AS b
						INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
					WHERE b.Product = 'TIP'
				END

				IF EXISTS (	SELECT 1
							FROM #PagingData AS b
								INNER JOIN dbo.match14 AS m14 WITH (NOLOCK) ON m14.matchid = b.MatchId
							WHERE b.Product = 'TIP')
				BEGIN
					UPDATE b
					SET
						LeagueId = m14.leagueid,
						HomeId = m14.homeid,
						AwayId = m14.awayid,
						EventDate = m14.GlobalShowTime
					FROM #PagingData AS b
						INNER JOIN dbo.match14 AS m14 WITH (NOLOCK) ON m14.matchid = b.MatchId
					WHERE b.Product = 'TIP'
				END

				IF EXISTS (	SELECT 1
							FROM #PagingData AS b
								INNER JOIN bodb_Archive.dbo.match_bk AS mbk WITH (NOLOCK) ON mbk.matchid = b.MatchId
							WHERE b.Product = 'TIP')
				BEGIN
					UPDATE b
					SET
						LeagueId = mbk.leagueid,
						HomeId = mbk.homeid,
						AwayId = mbk.awayid,
						EventDate = mbk.GlobalShowTime
					FROM #PagingData AS b
						INNER JOIN bodb_Archive.dbo.match_bk AS mbk WITH (NOLOCK) ON mbk.matchid = b.MatchId
					WHERE b.Product = 'TIP'
				END
			END
		END
	END

	-- Get currency name
	DECLARE @CurrencyName NVARCHAR(50)

	SELECT @CurrencyName = ex.currency
	FROM dbo.custInfo AS ci WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	WHERE ci.custid = @CustId

	SELECT
		b.TransId,
		b.RefNo,
		b.CustId,
		b.Currency,
		b.SportType,
		b.BetType,
		b.BetId,
		b.BetTeam,
		b.Hdp1,
		b.Hdp2,
		b.OddsId,
		b.OddsType,
		b.Odds,
		b.MOdds,
		b.OddsSpread,
		CAST(b.Stake * ISNULL(@Rate, 1) AS DECIMAL(19, 8)) AS Stake,
		CAST(b.Actual_Stake * ISNULL(@Rate, 1) AS DECIMAL(19, 8)) AS Actual_Stake,
		CAST(b.WinLost * ISNULL(@Rate, 1) AS DECIMAL(19, 8)) AS WinLost,
		CAST(b.LicenseeWL * ISNULL(@Rate, 1) AS DECIMAL(19, 8)) AS LicenseeWL,
		CAST(b.PlayerComm * ISNULL(@Rate, 1) AS DECIMAL(19, 8)) AS PlayerComm,
		CAST(b.Comm * ISNULL(@Rate, 1) AS DECIMAL(19, 8)) AS Comm,
		b.Status,
		b.SettlementStatus,
		b.TransDate,
		b.WinLostDate,
		b.LiveIndicator,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.Ip,
		b.BetFrom,
		b.LeagueId,
		b.LeagueGroupId,
		b.MatchId,
		b.MatchCode,
		b.Race,
		b.EventDate,
		b.HomeId,
		b.AwayId,
		b.IsNeutral,
		b.ShowTime,
		b.BetCheck,
		b.ComStatus,
		b.TransDesc,
		b.BetdaqId,
		b.ExtraInfo,
		b.OriginalStake * ISNULL(@Rate, 1) AS OriginalStake,
		b.OriginalBetType,
		b.WalletType,
		b.RefCode,
		b.SiteId
	FROM #PagingData AS b
	ORDER BY b.RowNum ASC

	SELECT DISTINCT
		RefNo,
		Odds,
		Stake,
		Status,
		APositionTaking,
		BetType,
		BetTeam
	FROM @DetailData

	DROP TABLE #Data
	DROP TABLE #PagingData
END
GO
