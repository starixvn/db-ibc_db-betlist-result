/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Statement_Mem]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@Date			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@ProductCode	VARCHAR(200),
	@TransType		TINYINT			= 1,
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@Sort			NVARCHAR(50)	= N'TransDate ASC',
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

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, RefTable TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, RefTable, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductCode, @IsTest)
	WHERE BetType NOT IN (904, 914, 999)
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
		Tranid3rd			NVARCHAR(64),
		TableID				TINYINT,
		Product				VARCHAR(30),
		RefTable			TINYINT
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
		Tranid3rd			NVARCHAR(64),
		TableID				TINYINT,
		Product				VARCHAR(30),
		RefTable			TINYINT
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

	DECLARE @Currency	INT,
		@Rate			FLOAT = 1

	IF @HasError = 0
	BEGIN
		DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)
		DECLARE @_Date SMALLDATETIME

		SET @_Date = @Date

		-- bettrans range
		IF @_Date > @MoveBetsDay
		BEGIN
			-- bettrans
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				Recommend,
				Currency,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsId,
				OddsType,
				Odds,
				MOdds,
				OddsSpread,
				Stake,
				Actual_Stake,
				WinLost,
				LicenseeWL,
				PlayerComm,
				Comm,
				Status,
				SecAcceptFlag,
				CheckTime,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				BetFrom,
				MatchId,
				BetCheck,
				ComStatus,
				TransDesc,
				BetdaqId,
				ExtraInfo,
				WalletType,
				RefCode,
				TableID)
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
					TransId,
					RefNo,
					CustId,
					Recommend,
					Currency,
					BetType,
					Odds,
					Stake,
					Actual_Stake,
					Status,
					TransDate,
					WinLostDate,
					LiveIndicator,
					Ip,
					BetFrom,
					TransDesc,
					SiteId,
					ProductId,
					EventId,
					Custom1,
					Custom2,
					Custom3,
					Gameid3rd,
					Tranid3rd,
					TableID
				)
				SELECT
					b.translogid AS TransId,
					b.translogid AS RefNo,
					b.custid,
					b.recommend,
					b.currency,
					b.gameID AS BetType,
					b.odds,
					b.stake,
					b.actual_stake,
					b.status,
					b.transdate,
					b.transdate AS WinLostDate,
					b.liveindicator,
					b.ip,
					b.betfrom,
					b.transdesc,
					b.SiteId,
					b.productID,
					b.eventID,
					b.custom1,
					b.custom2,
					b.custom3,
					b.GameId3rd,
					b.TranId3rd,
					4 AS TableID
				FROM dbo.translog AS b WITH (NOLOCK)
				WHERE b.custid = @CustId
					AND b.winlostdate = @_Date
					AND b.statusID IN (0, 1)
			END
		END
		ELSE IF @_Date BETWEEN @BalanceUpDay AND @MoveBetsDay		-- bettrans14 range
		BEGIN
			-- bettrans14
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				Recommend,
				Currency,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsId,
				OddsType,
				Odds,
				MOdds,
				OddsSpread,
				Stake,
				Actual_Stake,
				WinLost,
				LicenseeWL,
				PlayerComm,
				Comm,
				Status,
				SecAcceptFlag,
				CheckTime,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				BetFrom,
				MatchId,
				BetCheck,
				ComStatus,
				TransDesc,
				BetdaqId,
				ExtraInfo,
				WalletType,
				RefCode,
				TableID)
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
				2 AS TableID
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @_Date
				AND 1 = CASE
							WHEN @TransType = 0 THEN 1
							WHEN @TransType = 1 AND b.statusID IN (111, 112, 113) THEN 1
							WHEN @TransType = 2 AND b.statusID IN (101, 102, 103) THEN 1
							ELSE 0
						END
		END
		ELSE IF @_Date < @BalanceUpDay		-- bettrans_bk range
		BEGIN
			-- bettrans_bk
			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				Recommend,
				Currency,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsId,
				OddsType,
				Odds,
				MOdds,
				OddsSpread,
				Stake,
				Actual_Stake,
				WinLost,
				LicenseeWL,
				PlayerComm,
				Comm,
				Status,
				SecAcceptFlag,
				CheckTime,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				BetFrom,
				MatchId,
				BetCheck,
				ComStatus,
				TransDesc,
				BetdaqId,
				ExtraInfo,
				WalletType,
				RefCode,
				TableID)
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
				dp.IP,
				b.betfrom,
				b.matchid,
				b.betcheck,
				b.comstatus,
				b.transdesc,
				b.betdaqid,
				b.ExtraInfo,
				b.WalletType,
				ISNULL(b.RefCode, 0) AS RefCode,
				3 AS TableID
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
			WHERE b.custid = @CustId
				AND b.winlostdate = @_Date
				AND 1 = CASE
							WHEN @TransType = 0 THEN 1
							WHEN @TransType = 1 AND b.statusID IN (111, 112, 113) THEN 1
							WHEN @TransType = 2 AND b.statusID IN (101, 102, 103) THEN 1
							ELSE 0
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
							WHEN s.ProductID = 73 THEN 'MGRNG'							-- MG-RNG
							WHEN s.ProductID = 74 THEN 'TIP'							-- Player Tips
							WHEN s.ProductID = 75 THEN 'JIG'							-- Jili
							WHEN s.ProductID = 76 THEN 'YB'								-- YeeBet
							WHEN s.ProductID = 77 THEN 'LG'								-- Virtual Sports 3
							WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
							WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'		-- Happy 5 Linked Games (Number Game)
							WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
							WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
							WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
							WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
							WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
							WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual Sports Racing
							ELSE 'Unknown'
						END,
				RefTable = s.RefTable
			FROM #Data AS b
				INNER JOIN @SportBettype AS s ON b.BetType = s.BetType

			DELETE b
			FROM #Data AS b
			WHERE NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
				OR Product = 'Unknown'
				OR Product IS NULL
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
							SELECT
								c.TransId AS RefNo,
								CASE
									WHEN Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
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
									WHEN c.Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') THEN ISNULL(SUM(brng.BetStake), 0)
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
								- SUM(blc.winlost - blc.actual_stake) AS LicenseeWL,
								SUM(blc.playercomm) AS Commission,
								SUM(blc.comm) AS Comm,
								0 AS OddsSpread
							FROM #Data AS c
								INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
							WHERE c.RefTable = 2 AND blc.statusID NOT IN (0, 1)
							GROUP BY
								c.TransId,
								c.Product
						END
						ELSE IF @TransType = 3		-- Running
						BEGIN
							INSERT INTO @TmpData
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

				-- Get sort text
				IF @BaseCurrency <> ''
					AND (@Sort LIKE '%Stake%' OR @Sort LIKE '%WinLost%' OR @Sort LIKE '%LicenseeWL%')
				BEGIN
					DECLARE @CharIndex TINYINT

					SELECT @CharIndex = CHARINDEX(' ', @Sort, 1)

					SELECT @Sort = SUBSTRING(@Sort, 0, @CharIndex) + ' * ISNULL(@Rate, 1)' + SUBSTRING(@Sort, @CharIndex, LEN(@Sort))
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
								ROW_NUMBER() OVER (ORDER BY ' + @Sort + N') AS RowNum,
								d.*
							FROM #Data AS d
						) AS a
					WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
					ORDER BY a.RowNum'

				INSERT INTO #PagingData
				EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

				-- bettrans range
				IF @_Date > @MoveBetsDay
				BEGIN
					UPDATE b
					SET
						TransId = CASE
									WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END,
						SportType = CASE
										WHEN b.Product IN ('OneRNG', 'CC', 'SG', 'NPHP', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK', 'H5LG', 'SLT', 
											'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'TIP', 'JIG', 'YB', 'MGRNG') THEN b.matchid		-- ONERnG, Card Club, NPH Promotion
										WHEN b.Product = 'Keno' THEN 202	-- Keno
										WHEN b.Product = 'Lottery' THEN 220	-- Lottery
										WHEN b.Product = 'AllBet' THEN 211	-- AllBet
										WHEN b.Product = 'VB' THEN 212		-- Macau Games
										WHEN b.Product = 'PP' THEN 248		-- Pragmatic Casino
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.sporttype
										WHEN b.Product IN ('BTC') THEN m3rd.SportType
										WHEN b.Product IN ('Outright') THEN l.sporttype
										WHEN b.Product IN ('VR') THEN vr.SportType
										ELSE 0
									END,
						BetTeam = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC', 'LG') THEN b.betteam
										ELSE ''
									END,
						Hdp1 = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'BTC', 'LG') THEN b.hdp1
									ELSE 0
								END,
						Hdp2 = CASE
									WHEN b.Product IN ('SB', 'CO', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'LG') THEN b.hdp2
									ELSE 0
								END,
						OddsType = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'LG') THEN b.oddstype
										ELSE 0
									END,
						Odds = CASE
									WHEN b.Product IN ('VB', 'PP', 'OneRNG', 'Allbet', 'SBC', 'VGA', 'SG') AND x.Odds IS NOT NULL THEN x.Odds
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'OneRNG', 'Keno', 'ParlayVS2', 'Lottery', 
										'VRG', 'TG', 'I4D', 'PP', 'SBC', 'SLT', 'VGA', 'H5LG', 'SG', 'VS3', 'BTC', 'LG') THEN b.odds
									ELSE 0
								END,
						MOdds = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'LG') THEN b.modds
									ELSE 0
								END,
						Stake = CASE
									WHEN b.RefTable IN (1, 2) AND x.Stake IS NOT NULL THEN x.Stake
									ELSE b.stake
								END,
						Actual_Stake = CASE
										WHEN b.RefTable IN (1, 2) AND x.Actual_Stake IS NOT NULL THEN x.Actual_Stake
										ELSE b.actual_stake
									END,
						Status = CASE
									WHEN b.RefTable IN (1, 2) AND x.Status IS NOT NULL THEN x.Status
									WHEN b.Product = 'SB' AND b.bettype NOT IN (9, 29)
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
									WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
									WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
									ELSE b.status
								END,
						SettlementStatus = CASE
												WHEN b.Product = 'SB' THEN ISNULL(m.SettlementStatus, 0)
												ELSE 0
											END,
						WinLost = CASE
										WHEN b.RefTable IN (1, 2) AND x.WinLost IS NOT NULL THEN x.WinLost
										ELSE b.WinLost
									END,
						LicenseeWL = CASE
										WHEN b.RefTable IN (1, 2) AND x.LicenseeWL IS NOT NULL THEN x.LicenseeWL
										ELSE b.LicenseeWL
									END,
						PlayerComm = CASE
										WHEN b.RefTable IN (1, 2) AND x.PlayerComm IS NOT NULL THEN x.PlayerComm
										ELSE b.PlayerComm
									END,
						Comm = CASE
										WHEN b.RefTable IN (1, 2) AND x.Comm IS NOT NULL THEN x.Comm
										ELSE b.Comm
									END,
						LiveIndicator = CASE
											WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'LG') THEN b.liveindicator
											ELSE 0
										END,
						LiveHomeScore = CASE
											WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'LG') THEN b.livehomescore
											ELSE 0
										END,
						LiveAwayScore = CASE
											WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'LG') THEN b.liveawayscore
											ELSE 0
										END,
						LeagueId = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.leagueid
										WHEN b.Product IN ('Outright') THEN o.leagueid
										WHEN b.Product IN ('VR') THEN vr.LeagueID
										ELSE 0
									END,
						MatchId = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'BTC', 'LG') THEN b.matchid
										WHEN b.Product IN ('TIP') THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
										ELSE 0
									END,
						MatchCode = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.matchcode
										WHEN b.Product IN ('Outright') THEN o.matchcode
										WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
										ELSE ''
									END,
						Race = CASE
									WHEN b.Product IN ('Outright') THEN o.groupmatch
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
									ELSE ''
								END,
						EventDate = CASE
										WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
										WHEN b.Product IN ('NG', 'VS', 'VS2') THEN m.eventdate
										WHEN b.Product IN ('BTC') THEN m3rd.EndTime
										WHEN b.Product IN ('Outright') THEN o.eventdate
										WHEN b.Product IN ('VR') THEN vo.EventDate
										ELSE b.winlostdate
									END,
						HomeId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.homeid
									WHEN b.Product IN ('Outright') THEN o.teamid
									WHEN b.Product IN ('VR') THEN vo.RacerID
									ELSE 0
								END,
						AwayId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.awayid
									ELSE 0
								END,
						BetStatus = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.betstatus
										ELSE ''
									END,
						IsNeutral = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
										ELSE 0
									END,
						ShowTime = CASE
										WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
										WHEN b.Product IN ('SB', 'CO', 'NG') THEN ISNULL(m.showtime, '')
										WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
										ELSE ''
									END,
						BetCheck = CASE
										WHEN b.Product IN ('SB', 'CO', 'Parlay', 'ParlayVS2', 'VRG', 'H5LG', 'SLT') THEN ISNULL(b.betcheck, '')
										WHEN b.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
										ELSE ''
									END,
						ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
						TransDesc = CASE
										WHEN b.Product IN ('SB', 'CO', 'VS2', 'OneRNG', 'CC', 'SG', 'Keno', 'VB', 'Lottery', 'PP', 
											'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'VS3', 'LG') THEN ISNULL(b.transdesc, '')
										ELSE ''
									END,
						OddsSpread = CASE
										WHEN b.Product IN ('PP', 'SBC', 'VGA', 'SG') AND x.OddsSpread IS NOT NULL THEN x.OddsSpread
										WHEN b.Product IN ('SB', 'CO', 'PP', 'SBC', 'VGA', 'SG') THEN ISNULL(b.oddsspread, 0)
										ELSE 0
									END,
						BetdaqId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
						ExtraInfo = CASE
										WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'NPHP', 'Keno', 'Lottery', 'TG', 'SLT', 'NG', 'H5LG', 'VS', 'VS2', 
											'ParlayVS2', 'VR', 'VS3', 'BTC', 'TIP', 'LG') THEN ISNULL(b.ExtraInfo, '')
										ELSE ''
									END,
						OriginalStake = CASE
											WHEN b.Product IN ('SB') AND b.ExtraInfo LIKE '%p25%' THEN
												ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
											ELSE 0
										END,
						OriginalBetType = CASE
												WHEN b.Product IN ('SB') AND b.stake <> 0 THEN -1
												WHEN b.Product IN ('CO') THEN b.OriginalBetType
												ELSE 0
											END,
						WalletType = CASE
										WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
										ELSE 0
									END,
						RefCode = CASE
										WHEN b.Product IN ('SB') THEN ISNULL(b.RefCode, 0)
										ELSE 0
									END,
						SiteId = CASE
									WHEN b.Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
									ELSE ''
								END
					FROM #PagingData AS b
						LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') AND b.matchid = m.matchid
						LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON b.Product IN ('BTC') AND m3rd.Match3rdId = b.matchid
						LEFT JOIN @TmpData AS x
							ON b.RefTable IN (1, 2)
							AND b.Winlostdate >= @Yesterday
							AND x.RefNo = b.transid
						LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
						LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
						LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
						LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
					WHERE b.TableID = 1

					-- Get match info for Player Tips
					IF EXISTS (SELECT 1 FROM #PagingData WHERE TableID = 1 AND Product = 'TIP')
					BEGIN
						UPDATE b
						SET
							LeagueId = m.leagueid,
							HomeId = m.homeid,
							AwayId = m.awayid,
							EventDate = m.GlobalShowTime
						FROM #PagingData AS b
							INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
						WHERE b.TableID = 1 AND b.Product = 'TIP'
					END

					-- translog
					UPDATE b
					SET SportType = CASE
										WHEN b.Product = 'Keno' THEN 202
										WHEN b.Product = 'Lottery' THEN 220		-- Lottery
										WHEN b.Product IN ('VRG', 'TG', 'I4D', 'H5LG', 'SLT', 'VS3') THEN b.productID	-- Virtual Games, Table Games
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
						EventDate = b.winlostdate,
						HomeId = 0,
						AwayId = 0,
						IsNeutral = 0,
						ShowTime = '',
						BetCheck = CASE
										WHEN b.Product IN ('Keno') THEN ISNULL(b.Custom2, '')
										WHEN b.Product IN ('VRG', 'H5LG', 'SLT') THEN b.Gameid3rd
										WHEN b.Product IN ('VS3') THEN ISNULL(b.Custom1, '')
										ELSE ''
									END,
						ComStatus = 0,
						OddsSpread = 0,
						BetdaqId = -1,
						ExtraInfo = ''
					FROM #PagingData AS b
					WHERE TableID = 4

					-- Get ticket detail
					-- Virtual Sports Racing
					INSERT INTO @DetailData
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
					UPDATE b
					SET
						TransId = CASE
									WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END,
						SportType = CASE
										WHEN b.Product IN ('OneRNG', 'CC', 'SG', 'NPHP', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK', 'H5LG', 'SLT', 
											'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'TIP', 'JIG', 'YB', 'MGRNG') THEN b.matchid		-- ONERnG, Card Club, NPH Promotion
										WHEN b.Product = 'Keno' THEN 202	-- Keno
										WHEN b.Product = 'Lottery' THEN 220	-- Lottery
										WHEN b.Product = 'AllBet' THEN 211	-- AllBet
										WHEN b.Product = 'VB' THEN 212		-- Macau Games
										WHEN b.Product = 'PP' THEN 248		-- Pragmatic Casino
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.sporttype
										WHEN b.Product IN ('BTC') THEN m3rd.SportType
										WHEN b.Product IN ('Outright') THEN l.sporttype
										WHEN b.Product IN ('VR') THEN vr.SportType
										ELSE 0
									END,
						BetTeam = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC', 'LG') THEN b.betteam
										ELSE ''
									END,
						Hdp1 = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'BTC', 'LG') THEN b.hdp1
									ELSE 0
								END,
						Hdp2 = CASE
									WHEN b.Product IN ('SB', 'CO', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'LG') THEN b.hdp2
									ELSE 0
								END,
						OddsType = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'LG') THEN b.oddstype
										ELSE 0
									END,
						Odds = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'OneRNG', 'Keno', 'ParlayVS2', 'Lottery', 
										'VRG', 'TG', 'I4D', 'PP', 'SBC', 'SLT', 'VGA', 'H5LG', 'SG', 'VS3', 'BTC', 'LG') THEN b.odds
									ELSE 0
								END,
						MOdds = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'LG') THEN b.modds
									ELSE 0
								END,
						Status = CASE
									WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
									WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
									ELSE b.status
								END,
						SettlementStatus = 0,
						LiveIndicator = CASE
											WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'LG') THEN b.liveindicator
											ELSE 0
										END,
						LiveHomeScore = CASE
											WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'LG') THEN b.livehomescore
											ELSE 0
										END,
						LiveAwayScore = CASE
											WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'LG') THEN b.liveawayscore
											ELSE 0
										END,
						LeagueId = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.leagueid
										WHEN b.Product IN ('Outright') THEN o.leagueid
										WHEN b.Product IN ('VR') THEN vr.LeagueID
										ELSE 0
									END,
						MatchId = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'BTC', 'LG') THEN b.matchid
										WHEN b.Product IN ('TIP') THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
										ELSE 0
									END,
						MatchCode = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.matchcode
										WHEN b.Product IN ('Outright') THEN o.matchcode
										WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
										ELSE ''
									END,
						Race = CASE
									WHEN b.Product IN ('Outright') THEN o.groupmatch
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
									ELSE ''
								END,
						EventDate = CASE
										WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
										WHEN b.Product IN ('NG', 'VS', 'VS2') THEN m.eventdate
										WHEN b.Product IN ('BTC') THEN m3rd.EndTime
										WHEN b.Product IN ('Outright') THEN o.eventdate
										WHEN b.Product IN ('VR') THEN vo.EventDate
										ELSE b.winlostdate
									END,
						HomeId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.homeid
									WHEN b.Product IN ('Outright') THEN o.teamid
									WHEN b.Product IN ('VR') THEN vo.RacerID
									ELSE 0
								END,
						AwayId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.awayid
									ELSE 0
								END,
						BetStatus = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.betstatus
										ELSE ''
									END,
						IsNeutral = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
										ELSE 0
									END,
						ShowTime = CASE
										WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
										WHEN b.Product IN ('SB', 'CO', 'NG') THEN ISNULL(m.showtime, '')
										WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
										ELSE ''
									END,
						BetCheck = CASE
										WHEN b.Product IN ('SB', 'CO', 'Parlay', 'ParlayVS2', 'VRG', 'H5LG', 'SLT') THEN ISNULL(b.betcheck, '')
										WHEN b.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
										ELSE ''
									END,
						ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
						TransDesc = CASE
										WHEN b.Product IN ('SB', 'CO', 'VS2', 'OneRNG', 'CC', 'SG', 'Keno', 'VB', 'Lottery', 'PP', 
											'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'VS3', 'LG') THEN ISNULL(b.transdesc, '')
										ELSE ''
									END,
						OddsSpread = CASE
										WHEN b.Product IN ('SB', 'CO', 'PP', 'SBC', 'VGA', 'SG') THEN ISNULL(b.oddsspread, 0)
										ELSE 0
									END,
						BetdaqId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
						ExtraInfo = CASE
										WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'NPHP', 'Keno', 'Lottery', 'TG', 'SLT', 'NG', 'H5LG', 'VS', 'VS2', 
											'ParlayVS2', 'VR', 'VS3', 'BTC', 'TIP', 'LG') THEN ISNULL(b.ExtraInfo, '')
										ELSE ''
									END,
						OriginalStake = CASE
											WHEN b.Product IN ('SB') AND b.ExtraInfo LIKE '%p25%' THEN
												ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
											ELSE 0
										END,
						OriginalBetType = CASE
												WHEN b.Product IN ('SB') AND b.stake <> 0 THEN -1
												WHEN b.Product IN ('CO') THEN b.OriginalBetType
												ELSE 0
											END,
						WalletType = CASE
										WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
										ELSE 0
									END,
						RefCode = CASE
										WHEN b.Product IN ('SB') THEN ISNULL(b.RefCode, 0)
										ELSE 0
									END,
						SiteId = CASE
									WHEN b.Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
									ELSE ''
								END
					FROM #PagingData AS b
						LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') AND b.matchid = m.matchid
						LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON b.Product IN ('BTC') AND m3rd.Match3rdId = b.matchid
						LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
						LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
						LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
						LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
					WHERE b.TableID = 2

					-- Get match info for Player Tips
					IF EXISTS (SELECT 1 FROM #PagingData WHERE TableID = 2 AND Product = 'TIP')
					BEGIN
						UPDATE b
						SET
							LeagueId = m.leagueid,
							HomeId = m.homeid,
							AwayId = m.awayid,
							EventDate = m.GlobalShowTime
						FROM #PagingData AS b
							INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId
						WHERE b.TableID = 2 AND b.Product = 'TIP'
					END

					-- Get ticket detail
					-- Virtual Sports Racing
					INSERT INTO @DetailData
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
					UPDATE b
					SET
						TransId = CASE
									WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
									ELSE b.transid
								END,
						SportType = CASE
										WHEN b.Product IN ('OneRNG', 'CC', 'SG', 'NPHP', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK', 'H5LG', 'SLT', 
											'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'TIP', 'JIG', 'YB', 'MGRNG') THEN b.matchid		-- ONERnG, Card Club, NPH Promotion
										WHEN b.Product = 'Keno' THEN 202	-- Keno
										WHEN b.Product = 'Lottery' THEN 220	-- Lottery
										WHEN b.Product = 'AllBet' THEN 211	-- AllBet
										WHEN b.Product = 'VB' THEN 212		-- Macau Games
										WHEN b.Product = 'PP' THEN 248		-- Pragmatic Casino
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.sporttype
										WHEN b.Product IN ('BTC') THEN m3rd.sporttype
										WHEN b.Product IN ('Outright') THEN l.sporttype
										WHEN b.Product IN ('VR') THEN vr.SportType
										ELSE 0
									END,
						BetTeam = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC', 'LG') THEN b.betteam
										ELSE ''
									END,
						Hdp1 = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'BTC', 'LG') THEN b.hdp1
									ELSE 0
								END,
						Hdp2 = CASE
									WHEN b.Product IN ('SB', 'CO', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'LG') THEN b.hdp2
									ELSE 0
								END,
						OddsType = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'LG') THEN b.oddstype
										ELSE 0
									END,
						Odds = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'OneRNG', 'Keno', 'ParlayVS2', 'Lottery', 
										'VRG', 'TG', 'I4D', 'PP', 'SBC', 'SLT', 'VGA', 'H5LG', 'SG', 'VS3', 'BTC', 'LG') THEN b.odds
									ELSE 0
								END,
						MOdds = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'LG') THEN b.modds
									ELSE 0
								END,
						Status = CASE
									WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
									WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
									ELSE b.status
								END,
						SettlementStatus = 0,
						LiveIndicator = CASE
											WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'LG') THEN b.liveindicator
											ELSE 0
										END,
						LiveHomeScore = CASE
											WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'LG') THEN b.livehomescore
											ELSE 0
										END,
						LiveAwayScore = CASE
											WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'LG') THEN b.liveawayscore
											ELSE 0
										END,
						LeagueId = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.leagueid
										WHEN b.Product IN ('Outright') THEN o.leagueid
										WHEN b.Product IN ('VR') THEN vr.LeagueID
										ELSE 0
									END,
						MatchId = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'BTC', 'LG') THEN b.matchid
										WHEN b.Product IN ('TIP') THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
										ELSE 0
									END,
						MatchCode = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.matchcode
										WHEN b.Product IN ('Outright') THEN o.matchcode
										WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
										ELSE ''
									END,
						Race = CASE
									WHEN b.Product IN ('Outright') THEN o.groupmatch
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
									ELSE ''
								END,
						EventDate = CASE
										WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
										WHEN b.Product IN ('NG', 'VS', 'VS2') THEN m.eventdate
										WHEN b.Product IN ('BTC') THEN m3rd.EndTime
										WHEN b.Product IN ('Outright') THEN o.eventdate
										WHEN b.Product IN ('VR') THEN vo.EventDate
										ELSE b.winlostdate
									END,
						HomeId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.homeid
									WHEN b.Product IN ('Outright') THEN o.teamid
									WHEN b.Product IN ('VR') THEN vo.RacerID
									ELSE 0
								END,
						AwayId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.awayid
									ELSE 0
								END,
						BetStatus = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.betstatus
										ELSE ''
									END,
						IsNeutral = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
										ELSE 0
									END,
						ShowTime = CASE
										WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
										WHEN b.Product IN ('SB', 'CO', 'NG') THEN ISNULL(m.showtime, '')
										WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
										ELSE ''
									END,
						BetCheck = CASE
										WHEN b.Product IN ('SB', 'CO', 'Parlay', 'ParlayVS2', 'VRG', 'H5LG', 'SLT') THEN ISNULL(b.betcheck, '')
										WHEN b.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
										ELSE ''
									END,
						ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
						TransDesc = CASE
										WHEN b.Product IN ('SB', 'CO', 'VS2', 'OneRNG', 'CC', 'SG', 'Keno', 'VB', 'Lottery', 'PP', 
											'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'VS3', 'LG') THEN ISNULL(b.transdesc, '')
										ELSE ''
									END,
						OddsSpread = CASE
										WHEN b.Product IN ('SB', 'CO', 'PP', 'SBC', 'VGA', 'SG') THEN ISNULL(b.oddsspread, 0)
										ELSE 0
									END,
						BetdaqId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
						ExtraInfo = CASE
										WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'NPHP', 'Keno', 'Lottery', 'TG', 'SLT', 'NG', 'H5LG', 'VS', 'VS2', 
											'ParlayVS2', 'VR', 'VS3', 'BTC', 'TIP', 'LG') THEN ISNULL(b.ExtraInfo, '')
										ELSE ''
									END,
						OriginalStake = CASE
											WHEN b.Product IN ('SB') AND b.ExtraInfo LIKE '%p25%' THEN
												ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
											ELSE 0
										END,
						OriginalBetType = CASE
												WHEN b.Product IN ('SB') AND b.stake <> 0 THEN -1
												WHEN b.Product IN ('CO') THEN b.OriginalBetType
												ELSE 0
											END,
						WalletType = CASE
										WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
										ELSE 0
									END,
						RefCode = CASE
										WHEN b.Product IN ('SB') THEN ISNULL(b.RefCode, 0)
										ELSE 0
									END,
						SiteId = CASE
									WHEN b.Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
									ELSE ''
								END
					FROM #PagingData AS b
						LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') AND b.matchid = m.matchid
						LEFT JOIN bodb_Archive.dbo.Match3rd_bk AS m3rd WITH (NOLOCK) ON b.Product IN ('BTC') AND m3rd.Match3rdId = b.matchid
						LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
						LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
						LEFT JOIN bodb_Archive.dbo.VSOutright_bk AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
						LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
					WHERE b.TableID = 3

					-- Get match info for Player Tips
					IF EXISTS (SELECT 1 FROM #PagingData WHERE TableID = 3 AND Product = 'TIP')
					BEGIN
						UPDATE b
						SET
							LeagueId = m.leagueid,
							HomeId = m.homeid,
							AwayId = m.awayid,
							EventDate = m.GlobalShowTime
						FROM #PagingData AS b
							INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId
						WHERE b.TableID = 3 AND b.Product = 'TIP'
					END

					-- Get ticket detail
					-- Virtual Sports Racing
					INSERT INTO @DetailData
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
		b.Stake * ISNULL(@Rate, 1) AS Stake,
		b.Actual_Stake * ISNULL(@Rate, 1) AS Actual_Stake,
		b.WinLost * ISNULL(@Rate, 1) AS WinLost,
		b.LicenseeWL * ISNULL(@Rate, 1) AS LicenseeWL,
		b.PlayerComm * ISNULL(@Rate, 1) AS PlayerComm,
		b.Comm * ISNULL(@Rate, 1) AS Comm,
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

	SELECT DISTINCT * FROM @DetailData

	DROP TABLE #Data
	DROP TABLE #PagingData
END
GO
