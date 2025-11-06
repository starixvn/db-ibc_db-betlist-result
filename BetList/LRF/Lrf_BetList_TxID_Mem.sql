/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_TxID_Mem]
	@AgentList			VARCHAR(MAX),
	@TxId				VARCHAR(100),
	@CustId				INT				= 0,
	@Username			VARCHAR(50)		= '',
	@ExcludeBettrans	BIT				= 0,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@BaseCurrency		VARCHAR(12)		= ''
AS

/*
	Created: Kos@20180604
	Task: Statement Service - Search By Licensee transaction ID
	DB: DBACC.bodb02

	Revisions:
		- 20200529@Kos: Created [#Redmine: 80941]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211029@Kos: Decompress IP in bk range [Redmine: 162342]
		- 20220110@Kos: Support TxId for 3rd products [Redmine: #166706]
		- 20220401@Kos: Support TxId for Vgaming [Redmine: #170054]
		- 20220428@Kos: Support Bitcoin [RedmineID: #160160]
		- 20220727@Kos: Scale out DBTRANS [Redmine: #175297]
					- Add new input param @ExcludeBettrans BIT
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20221116@Kos: Support Player Tips [Redmine: 180590]
		- 20221220@Kos: Remove inactive products FW [Redmine: 181424]
		- 20230404@Kos: Extend betfrom length [Redmine: #178059]
		- 20230818@Kos: Hotfix - Incorrect display Virtual Sports and Virtual Sports 2 [Redmine: #192481]
		- 20230905@Kos: Support TxId for MaxGame [Redmine: 193273]
		- 20231019@Kos: Adjust due to new column ExtraInfo [Redmine: 195780]
					- Return new JackpotInfo column
		- 20231026@Kos: Support Virtual Sports 3 [Redmine: 190908]
		- 20240102@Kos: Extend data type [Redmine: 198966]
		- 20240425@Kos: Return LeagueGroupId to support Jollysports [Redmine: #203258]
		- 20240605@Kos: Support Virtual Sports 4 [Redmine: 199347]
		- 20240619@Kos: Hotfix - Missing TranId3rd for Sports Lottery and Virtual Games [Redmine: 206758]
		- 20240919@Kos: Support BetRadar Horse Racing [Redmine: #210808]
		- 20241018@Kos: Enhance match info for Player Tips [Redmine: 210279]
		- 20241028@Kos: Support Virtual Sports 6 [Redmine: 212446]
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]
		- 20250313@Kos: Remove BA [RedmineID: #216882]
		- 20250318@Kos: Support Virtual Sports 5 [Redmine: 207582]
		- 20250401@Kos: Support Virtual Sports 7 [Redmine: 219083]
		- 20251028@Kelvin: Integrate - Jacktime - Basketball Main Bettype Hybrid Parlay [#Redmine: 242357]
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
	DECLARE @SportBettype TABLE ( ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, RefTable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype (ProductID, Bettype, EventType, RefTable)
	SELECT ProductID, BetType, EventType, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 3, 5, 8, 27, 28, 40, 60, 63, 66, 69, 71, 74, 77, 83, 88, 106)
		AND BetType NOT BETWEEN 801 AND 899
		AND BetType NOT IN (901, 902, 903, 904)

	-- Get CustId in case of inputting Username
	IF @CustId = 0 AND @Username <> ''
	BEGIN
		SET @CustId = -1

		SELECT @CustId = custid
		FROM dbo.Customer AS c WITH (NOLOCK)
		WHERE EXISTS (SELECT 1 FROM @TempAg WHERE CustId = c.recommend)
			AND c.username = @Username

		IF @CustId = -1
		BEGIN
			SELECT @CustId = custid
			FROM dbo.Customer AS c WITH (NOLOCK)
			WHERE EXISTS (SELECT 1 FROM @TempAg WHERE CustId = c.recommend)
				AND c.username2 LIKE + '%$' + @Username
		END
	END

	DECLARE @Data TABLE (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Currency			SMALLINT,
		Recommend			INT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
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
		MatchCode			NVARCHAR(1000),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		Placing				NVARCHAR(20),
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(200),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		JackpotInfo			VARCHAR(50),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		SiteId				VARCHAR(20),
		WhTicket			TINYINT
	)
	
	DECLARE @Detail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10)
	)

	DECLARE
		@TransId		BIGINT,
		@WinLostDate	SMALLDATETIME,
		@Recommend		INT,
		@Currency		SMALLINT,
		@BetType		SMALLINT,
		@RefCode		BIGINT		= 0,
		@ProductId		TINYINT,
		@EventType		TINYINT,
		@RefTable		TINYINT,
		@Product		VARCHAR(30),
		@WhTicket		TINYINT		= 0,
		@BonusTransId	BIGINT		= 0

	IF @CustId NOT IN (-1, 0)
	BEGIN
		-- Bettrans range
		IF @ExcludeBettrans = 0
		BEGIN
			SELECT TOP(1)
				@TransId = b.transid,
				@CustId = b.custid,
				@WinLostDate = b.winlostdate,
				@Recommend = b.recommend,
				@Currency = b.currency,
				@BetType = b.bettype,
				@RefCode = b.RefCode,
				@ProductId = s.ProductID,
				@EventType = s.EventType,
				@RefTable = s.RefTable,
				@WhTicket = 2		-- bettrans
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate > @MoveBetsDay
				AND @TxId = CASE
								WHEN b.ExtraInfo LIKE '%p106%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p106/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p88%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p88/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p83%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p83/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p77%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p77/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p74%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p71%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p71/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p69%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p69/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p63%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p63/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p40%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p40/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p28%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p28/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p27%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p27/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p8%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p8/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p5%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p5/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p3%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p3/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b.ExtraInfo LIKE '%p1%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@lt)[1]','VARCHAR(100)'), 0)
							END
		END

		-- Bettrans14 range
		IF @WhTicket = 0
		BEGIN
			SELECT TOP(1)
				@TransId = b14.transid,
				@CustId = b14.custid,
				@WinLostDate = b14.winlostdate,
				@Recommend = b14.recommend,
				@Currency = b14.currency,
				@BetType = b14.bettype,
				@RefCode = b14.RefCode,
				@ProductId = s.ProductID,
				@EventType = s.EventType,
				@RefTable = s.RefTable,
				@WhTicket = 3		-- bettrans14
			FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b14.bettype = s.bettype
			WHERE b14.custid = @CustId
				AND b14.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
				AND @TxId = CASE
								WHEN b14.ExtraInfo LIKE '%p106%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p106/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p88%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p88/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p83%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p83/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p77%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p77/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p74%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p71%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p71/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p69%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p69/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p63%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p63/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p40%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p40/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p28%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p28/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p27%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p27/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p8%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p8/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p5%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p5/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p3%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p3/@lt)[1]','VARCHAR(100)'), 0)
								WHEN b14.ExtraInfo LIKE '%p1%'
									THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@lt)[1]','VARCHAR(100)'), 0)
							END
		END

		-- Bettrans_bk range
		IF @WhTicket = 0
		BEGIN
			SELECT TOP(1)
				@TransId = bk.transid,
				@CustId = bk.custid,
				@WinLostDate = bk.winlostdate,
				@Recommend = bk.recommend,
				@Currency = bk.currency,
				@BetType = bk.bettype,
				@RefCode = bk.RefCode,
				@ProductId = s.ProductID,
				@EventType = s.EventType,
				@RefTable = s.RefTable,
				@WhTicket = 4		-- bettrans_bk
			FROM bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK, INDEX = IX_custid)
				INNER JOIN @SportBettype AS s ON bk.bettype = s.bettype
			WHERE bk.custid = @CustId
				AND @TxId = CASE
								WHEN bk.ExtraInfo LIKE '%p106%'
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p106/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p88%'
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p88/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p71%'
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p71/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p1%' AND s.ProductID = 1
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p3%' AND s.ProductID = 3
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p3/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p5%' AND s.ProductID = 5
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p5/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p8%' AND s.ProductID = 8
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p8/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p27%' AND s.ProductID = 27
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p27/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p28%' AND s.ProductID = 28
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p28/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p40%' AND s.ProductID = 40
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p40/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p63%' AND s.ProductID = 63
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p63/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p69%'
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p69/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p74%'
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p77%'
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p77/@lt)[1]','VARCHAR(100)'), 0)
								WHEN bk.ExtraInfo LIKE '%p83%'
									THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p83/@lt)[1]','VARCHAR(100)'), 0)
							END
		END

		IF @WhTicket > 0
			AND NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = @Recommend AND Currency = @Currency)
		BEGIN
			SET @WhTicket = 0
		END
	END

	SET @Product = CASE
						WHEN @ProductId = 8 THEN 'Keno'
						WHEN @ProductId = 28 THEN 'Lottery'
						WHEN @ProductId = 40 THEN 'TG'								-- Table Games
						WHEN @ProductId = 63 THEN 'SLT'								-- Sports Lottery
						WHEN @ProductId = 69 THEN 'BTC'
						WHEN @ProductId = 74 THEN 'TIP'								-- Player Tips
						WHEN @ProductId = 77 THEN 'LG'								-- Virtual Sports 3
						WHEN @EventType = 0 AND @ProductId = 1 THEN 'Parlay'		-- Sportsbook Parlay
						WHEN @EventType = 0 AND @ProductId = 3 THEN 'H5LG'			-- Happy 5 Linked Games (Number Game)
						WHEN @EventType = 0 AND @ProductId = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
						WHEN @EventType = 1 AND @ProductId = 1 THEN 'SB'			-- Sportsbook
						WHEN @EventType = 1 AND @ProductId = 3 THEN 'NG'			-- Number Game
						WHEN @EventType = 1 AND @ProductId = 5 THEN 'VS'			-- Virtual Sports Sportsbook
						WHEN @EventType = 1 AND @ProductId = 27 THEN 'VS2'			-- Betradar Virtual Sports
						WHEN @EventType = 2 AND @ProductId = 1 THEN 'Outright'
						ELSE 'Unknown'
					END

	-- Get related Bonus/Cash ticket
	IF @RefCode <> 0 AND @Product = 'SB'
	BEGIN
		IF @WhTicket = 2
		BEGIN
			SELECT TOP(1) @BonusTransId = b.transid
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE b.custid = @CustId
				AND b.winlostdate = @WinLostDate
				AND b.RefCode = @RefCode
				AND b.transid <> @TransId
		END
		ELSE IF @WhTicket = 3
		BEGIN
			SELECT TOP(1) @BonusTransId = b14.transid
			FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
			WHERE b14.custid = @CustId
				AND b14.winlostdate = @WinLostDate
				AND b14.RefCode = @RefCode
				AND b14.transid <> @TransId
		END
		ELSE IF @WhTicket = 4
		BEGIN
			SELECT TOP(1) @BonusTransId = bk.transid
			FROM bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK, INDEX = IX_custid)
			WHERE bk.custid = @CustId
				AND bk.winlostdate = @WinLostDate
				AND bk.RefCode = @RefCode
				AND bk.transid <> @TransId
		END
	END

	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

	IF @WhTicket = 2	-- Bettrans
	BEGIN
		INSERT INTO @Data
		(
			TransId, RefNo, CustId, Currency, Recommend, SportType, BetType, BetId, BetTeam, Hdp1,
			Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, WinLost, LicenseeWL, PlayerComm,
			Comm, Status, SettlementStatus, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom,
			LeagueId, LeagueGroupId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral,
			Placing, ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, OriginalStake, OriginalBetType, WalletType,
			RefCode, SiteId, WhTicket
		)
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.currency,
			b.recommend,
			CASE
				WHEN @Product IN ('Keno', 'Lottery', 'TG', 'SLT', 'H5LG', 'TIP') THEN b.matchid
				WHEN @EventType = 1 THEN m.sporttype
				WHEN @EventType = 5 THEN m3rd.SportType
				WHEN @Product IN ('Outright') THEN l.sporttype
				WHEN @EventType = 3 THEN vr.SportType
				ELSE 0
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.modds,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			b.stake,
			b.actual_stake,
			b.winlost - b.actual_stake,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.playercomm,
			b.comm,
			CASE
				WHEN @Product IN ('SB')
					AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				WHEN @Product = 'Parlay' AND b.status = 'running' THEN
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
			END AS Status,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(m.SettlementStatus, 0)
				ELSE 0
			END AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.betfrom,
			CASE
				WHEN @EventType = 1 THEN m.leagueid
				WHEN @EventType = 5 THEN m3rd.League3rdId
				WHEN @Product IN ('Outright') THEN o.leagueid
				WHEN @EventType = 3 THEN vr.LeagueID
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB') THEN le.LeagueGroupID
				ELSE 0
			END AS LeagueGroupId,
			CASE
				WHEN @Product = 'TIP' THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
				ELSE b.matchid
			END AS MatchId,
			CASE
				WHEN @EventType = 1 THEN m.matchcode
				WHEN @Product IN ('Outright') THEN o.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN @Product IN ('Outright') THEN o.groupmatch
				ELSE ''
			END AS Race,
			CASE
				WHEN @Product IN ('SB') THEN m.GlobalShowTime
				WHEN @Product IN ('BTC') THEN m3rd.EndTime
				ELSE b.WinLostDate
			END AS EventDate,
			CASE
				WHEN @EventType = 1 THEN m.homeid
				WHEN @EventType = 5 THEN m3rd.HomeId
				WHEN @Product IN ('Outright') THEN o.teamid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @EventType = 1 THEN m.awayid
				WHEN @EventType = 5 THEN m3rd.AwayId
				ELSE 0
			END AS AwayId,
			CASE
				WHEN @EventType = 1 THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN @EventType = 1 THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			'' AS Placing,
			CASE
				WHEN @Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN @EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
				ELSE ''
			END AS ShowTime,
			CASE
				WHEN @Product IN ('SB', 'SLT', 'H5LG') THEN ISNULL(b.betcheck, '')
				WHEN @Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
				WHEN @EventType = 0 AND @RefTable = 0 THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @Product IN ('Keno', 'Lottery', 'TG', 'H5LG', 'SLT') THEN ISNULL(b.transdesc, '')
				WHEN b.bettype = 29 AND b.OddsSpread = 3 THEN ISNULL(b.transdesc, '')
				WHEN @EventType IN (1, 3, 5) THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			'' AS JackpotInfo,
			0 AS OriginalStake,
			CASE
				WHEN @Product IN ('SB') AND b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.WalletType, 0)
				ELSE 0
			END AS WalletType,
			CASE
				WHEN @Product IN ('SB') AND b.stake <> 0 THEN ISNULL(b.RefCode, 0)
				ELSE 0
			END AS RefCode,
			CASE
				WHEN @Product IN ('H5LG','SLT') THEN CONVERT(VARCHAR(20), b.BetdaqId)
				ELSE ''
			END AS SiteId,
			2 AS WhTicket
		FROM dbo.bettrans AS b WITH (NOLOCK)
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON @EventType = 1 AND b.matchid = m.matchid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON @Product IN ('SB') AND le.leagueid = m.leagueid
			LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON @EventType = 5 AND m3rd.Match3rdId = b.matchid
			LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON @Product IN ('Outright') AND b.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
			LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON @EventType = 3 AND vr.EventID = b.matchid
		WHERE b.transid IN (@TransId, @BonusTransId)
	END
	ELSE IF @WhTicket = 3		-- Bettrans14 range
	BEGIN
		INSERT INTO @Data
		(
			TransId, RefNo, CustId, Currency, Recommend, SportType, BetType, BetId, BetTeam, Hdp1,
			Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, WinLost, LicenseeWL, PlayerComm,
			Comm, Status, SettlementStatus, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom,
			LeagueId, LeagueGroupId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral,
			Placing, ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, OriginalStake, OriginalBetType, WalletType,
			RefCode, SiteId, WhTicket
		)
		SELECT
			b14.transid,
			b14.refno,
			b14.custid,
			b14.currency,
			b14.recommend,
			CASE
				WHEN @Product IN ('Keno', 'Lottery', 'TG', 'SLT', 'H5LG', 'TIP') THEN b14.matchid
				WHEN @EventType = 1 THEN m.sporttype
				WHEN @EventType = 5 THEN m3rd.SportType
				WHEN @Product IN ('Outright') THEN l.sporttype
				WHEN @EventType = 3 THEN vr.SportType
				ELSE 0
			END AS SportType,
			b14.bettype,
			ISNULL(b14.betid, 0) AS BetId,
			b14.betteam,
			b14.hdp1,
			b14.hdp2,
			b14.oddstype,
			b14.odds,
			b14.modds,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b14.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			b14.stake,
			b14.actual_stake,
			(b14.winlost - b14.actual_stake) AS WinLost,
			- (b14.winlost - b14.actual_stake) AS LicenseeWL,
			b14.playercomm,
			b14.comm,
			b14.status,
			0 AS SettlementStatus,
			b14.transdate,
			b14.winlostdate,
			b14.liveindicator,
			b14.livehomescore,
			b14.liveawayscore,
			b14.ip,
			b14.betfrom,
			CASE
				WHEN @EventType = 1 THEN m.leagueid
				WHEN @EventType = 5 THEN m3rd.League3rdId
				WHEN @Product IN ('Outright') THEN o.leagueid
				WHEN @EventType = 3 THEN vr.LeagueID
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB') THEN le.LeagueGroupID
				ELSE 0
			END AS LeagueGroupId,
			CASE
				WHEN @Product = 'TIP' THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
				ELSE b14.matchid
			END AS MatchId,
			CASE
				WHEN @EventType = 1 THEN m.matchcode
				WHEN @Product IN ('Outright') THEN o.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN @Product IN ('Outright') THEN o.groupmatch
				ELSE ''
			END AS Race,
			CASE
				WHEN @Product IN ('SB') THEN m.GlobalShowTime
				WHEN @Product IN ('BTC') THEN m3rd.EndTime
				ELSE b14.WinLostDate
			END AS EventDate,
			CASE
				WHEN @EventType = 1 THEN m.homeid
				WHEN @EventType = 5 THEN m3rd.HomeId
				WHEN @Product IN ('Outright') THEN o.teamid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @EventType = 1 THEN m.awayid
				WHEN @EventType = 5 THEN m3rd.AwayId
				ELSE 0
			END AS AwayId,
			CASE
				WHEN @EventType = 1 THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN @EventType = 1 THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			'' AS Placing,
			CASE
				WHEN @Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN @EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
				ELSE ''
			END AS ShowTime,
			CASE
				WHEN @Product IN ('SB', 'SLT', 'H5LG') THEN ISNULL(b14.betcheck, '')
				WHEN @Product IN ('Keno') THEN ISNULL(b14.ComStatus, '')
				WHEN @EventType = 0 AND @RefTable = 0 THEN ISNULL(b14.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @Product IN ('Keno', 'Lottery', 'TG', 'H5LG', 'SLT') THEN ISNULL(b14.transdesc, '')
				WHEN b14.bettype = 29 AND b14.OddsSpread = 3 THEN ISNULL(b14.transdesc, '')
				WHEN @EventType IN (1, 3, 5) THEN ISNULL(b14.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b14.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
			'' AS JackpotInfo,
			0 AS OriginalStake,
			CASE
				WHEN @Product IN ('SB') AND b14.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b14.WalletType, 0)
				ELSE 0
			END AS WalletType,
			CASE
				WHEN @Product IN ('SB') AND b14.stake <> 0 THEN ISNULL(b14.RefCode, 0)
				ELSE 0
			END AS RefCode,
			CASE
				WHEN @Product IN ('H5LG','SLT') THEN CONVERT(VARCHAR(20), b14.BetdaqId)
				ELSE ''
			END AS SiteId,
			3 AS WhTicket
		FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
			LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON @EventType = 1 AND b14.matchid = m.matchid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON @Product IN ('SB') AND le.leagueid = m.leagueid
			LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON @EventType = 5 AND m3rd.Match3rdId = b14.matchid
			LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON @Product IN ('Outright') AND b14.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
			LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON @EventType = 3 AND vr.EventID = b14.matchid
		WHERE b14.transid IN (@TransId, @BonusTransId)
	END
	ELSE IF @WhTicket = 4		-- Bettrans_bk range
	BEGIN
		INSERT INTO @Data
		(
			TransId, RefNo, CustId, Currency, Recommend, SportType, BetType, BetId, BetTeam, Hdp1,
			Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, WinLost, LicenseeWL, PlayerComm,
			Comm, Status, SettlementStatus, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom,
			LeagueId, LeagueGroupId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral,
			Placing, ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, OriginalStake, OriginalBetType, WalletType,
			RefCode, SiteId, WhTicket
		)
		SELECT
			bk.transid,
			bk.refno,
			bk.custid,
			bk.currency,
			bk.recommend,
			CASE
				WHEN @Product IN ('Keno', 'Lottery', 'TG', 'SLT', 'H5LG', 'TIP') THEN bk.matchid
				WHEN @EventType = 1 THEN m.sporttype
				WHEN @EventType = 5 THEN m3rd.SportType
				WHEN @Product IN ('Outright') THEN l.sporttype
				WHEN @EventType = 3 THEN vr.SportType
				ELSE 0
			END AS SportType,
			bk.bettype,
			ISNULL(bk.betid, 0) AS BetId,
			bk.betteam,
			bk.hdp1,
			bk.hdp2,
			bk.oddstype,
			bk.odds,
			bk.modds,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(bk.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			bk.stake,
			bk.actual_stake,
			(bk.winlost - bk.actual_stake) AS WinLost,
			- (bk.winlost - bk.actual_stake) AS LicenseeWL,
			bk.playercomm,
			bk.comm,
			bk.status,
			0 AS SettlementStatus,
			bk.transdate,
			bk.winlostdate,
			bk.liveindicator,
			bk.livehomescore,
			bk.liveawayscore,
			dp.IP,
			bk.betfrom,
			CASE
				WHEN @EventType = 1 THEN m.leagueid
				WHEN @EventType = 5 THEN m3rd.League3rdId
				WHEN @Product IN ('Outright') THEN o.leagueid
				WHEN @EventType = 3 THEN vr.LeagueID
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB') THEN le.LeagueGroupID
				ELSE 0
			END AS LeagueGroupId,
			CASE
				WHEN @Product = 'TIP' THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
				ELSE bk.matchid
			END AS MatchId,
			CASE
				WHEN @EventType = 1 THEN m.matchcode
				WHEN @Product IN ('Outright') THEN o.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN @Product IN ('Outright') THEN o.groupmatch
				ELSE ''
			END AS Race,
			CASE
				WHEN @Product IN ('SB') THEN m.GlobalShowTime
				WHEN @Product IN ('BTC') THEN m3rd.EndTime
				ELSE bk.WinLostDate
			END AS EventDate,
			CASE
				WHEN @EventType = 1 THEN m.homeid
				WHEN @EventType = 5 THEN m3rd.HomeId
				WHEN @Product IN ('Outright') THEN o.teamid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @EventType = 1 THEN m.awayid
				WHEN @EventType = 5 THEN m3rd.AwayId
				ELSE 0
			END AS AwayId,
			CASE
				WHEN @EventType = 1 THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN @EventType = 1 THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			'' AS Placing,
			CASE
				WHEN @Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN @EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
				ELSE ''
			END AS ShowTime,
			CASE
				WHEN @Product IN ('SB', 'SLT', 'H5LG') THEN ISNULL(bk.betcheck, '')
				WHEN @Product IN ('Keno') THEN ISNULL(bk.ComStatus, '')
				WHEN @EventType = 0 AND @RefTable = 0 THEN ISNULL(bk.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @Product IN ('Keno', 'Lottery', 'TG', 'H5LG', 'SLT') THEN ISNULL(bk.transdesc, '')
				WHEN bk.bettype = 29 AND bk.OddsSpread = 3 THEN ISNULL(bk.transdesc, '')
				WHEN @EventType IN (1, 3, 5) THEN ISNULL(bk.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(bk.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			ISNULL(bk.ExtraInfo, '') AS ExtraInfo,
			'' AS JackpotInfo,
			0 AS OriginalStake,
			CASE
				WHEN @Product IN ('SB') AND bk.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(bk.WalletType, 0)
				ELSE 0
			END AS WalletType,
			CASE
				WHEN @Product IN ('SB') AND bk.stake <> 0 THEN ISNULL(bk.RefCode, 0)
				ELSE 0
			END AS RefCode,
			CASE
				WHEN @Product IN ('H5LG','SLT') THEN CONVERT(VARCHAR(20), bk.BetdaqId)
				ELSE ''
			END AS SiteId,
			4 AS WhTicket
		FROM bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK)
			LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON @EventType = 1 AND bk.matchid = m.matchid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON @Product IN ('SB') AND le.leagueid = m.leagueid
			LEFT JOIN bodb_Archive.dbo.Match3rd_bk AS m3rd WITH (NOLOCK) ON @EventType = 5 AND m3rd.Match3rdId = bk.matchid
			LEFT JOIN bodb_Archive.dbo.Outright_bk AS o WITH (NOLOCK) ON @Product IN ('Outright') AND bk.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
			LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON @EventType = 3 AND vr.EventID = bk.matchid
			CROSS APPLY dbo.f_IP_Decompress(bk.ip) AS dp
		WHERE bk.transid IN (@TransId, @BonusTransId)
	END

	-- Get match info for Player Tips
	IF @Product = 'TIP'
	BEGIN
		IF EXISTS (	SELECT 1
					FROM @Data AS b
						INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId)
		BEGIN
			UPDATE b
			SET
				LeagueId = m.leagueid,
				HomeId = m.homeid,
				AwayId = m.awayid,
				EventDate = m.GlobalShowTime
			FROM @Data AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
		END
		ELSE IF EXISTS ( SELECT 1
						FROM @Data AS b
							INNER JOIN dbo.match14 AS m14 WITH (NOLOCK) ON m14.matchid = b.MatchId)
		BEGIN
			UPDATE b
			SET
				LeagueId = m14.leagueid,
				HomeId = m14.homeid,
				AwayId = m14.awayid,
				EventDate = m14.GlobalShowTime
			FROM @Data AS b
				INNER JOIN dbo.match14 AS m14 WITH (NOLOCK) ON m14.matchid = b.MatchId
		END
		ELSE
		BEGIN
			UPDATE b
			SET
				LeagueId = mbk.leagueid,
				HomeId = mbk.homeid,
				AwayId = mbk.awayid,
				EventDate = mbk.GlobalShowTime
			FROM @Data AS b
				INNER JOIN bodb_Archive.dbo.match_bk AS mbk WITH (NOLOCK) ON mbk.matchid = b.MatchId
		END
	END

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Display Cash/Bonus text for ticket from multiple wallets
	UPDATE @Data
	SET RefCode = 0
	WHERE RefCode <> 0

	IF @CustId NOT IN (-1, 0)
	BEGIN
		-- BettransRnG range
		IF @WhTicket = 0 AND @ExcludeBettrans = 0
		BEGIN
			SELECT TOP(1)
				@TransId = rng.transid,
				@CustId = rng.custid,
				@WinLostDate = rng.winlostdate,
				@Recommend = rng.recommend,
				@Currency = rng.currency,
				@BetType = rng.gameID,
				@ProductId = s.ProductID,
				@EventType = s.EventType,
				@WhTicket = 5		-- BettransRnG
			FROM dbo.bettransRnG AS rng WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = rng.gameID
			WHERE rng.custid = @CustId
				AND rng.winlostdate > @MoveBetsDay
				AND ISNULL(rng.Additional, '') LIKE '%lt=' + @TxId + '%'
		END

		-- Bettrans14 range
		IF @WhTicket = 0
		BEGIN
			SELECT TOP(1)
				@TransId = rng14.transid,
				@CustId = rng14.custid,
				@WinLostDate = rng14.winlostdate,
				@Recommend = rng14.recommend,
				@Currency = rng14.currency,
				@BetType = rng14.gameID,
				@ProductId = s.ProductID,
				@EventType = s.EventType,
				@WhTicket = 6		-- BettransRnG14
			FROM dbo.bettransRnG14 AS rng14 WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = rng14.gameID
			WHERE rng14.custid = @CustId
				AND rng14.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
				AND ISNULL(rng14.Additional, '') LIKE '%lt=' + @TxId + '%'
		END

		-- Bettrans_bk range
		IF @WhTicket = 0
		BEGIN
			SELECT TOP(1)
				@TransId = rngbk.transid,
				@CustId = rngbk.custid,
				@WinLostDate = rngbk.winlostdate,
				@Recommend = rngbk.recommend,
				@Currency = rngbk.currency,
				@BetType = rngbk.gameID,
				@ProductId = s.ProductID,
				@EventType = s.EventType,
				@WhTicket = 7		-- BettransRnG_bk
			FROM bodb_Archive.dbo.bettransRNG_bk AS rngbk WITH (NOLOCK, INDEX = IX_custid)
				INNER JOIN @SportBettype AS s ON s.Bettype = rngbk.gameID
			WHERE rngbk.custid = @CustId
				AND ISNULL(rngbk.Additional, '') LIKE '%lt=' + @TxId + '%'
		END

		IF @WhTicket > 0
			AND NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = @Recommend AND Currency = @Currency)
		BEGIN
			SET @WhTicket = 0
		END
	END

	SET @Product = CASE
						WHEN @ProductId = 60 THEN 'MXG'			-- MaxGame
						WHEN @ProductId = 66 THEN 'VGA'			-- Vgaming
						ELSE 'Unknown'
					END

	IF @Product <> 'Unknown'
	BEGIN
		-- BettransRnG
		IF @WhTicket = 5
		BEGIN
			INSERT INTO @Data
			(
				TransId, RefNo, CustId, Currency, Recommend, SportType, BetType, BetId, BetTeam, Hdp1,
				Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, WinLost, LicenseeWL, PlayerComm,
				Comm, Status, SettlementStatus, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom,
				LeagueId, LeagueGroupId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral,
				Placing, ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, OriginalStake, OriginalBetType, WalletType,
				RefCode, SiteId, WhTicket
			)
			SELECT
				rng.transid,
				rng.transid AS RefNo,
				rng.custid,
				rng.currency,
				rng.recommend,
				rng.productID AS SportType,
				rng.gameID AS BetType,
				0 AS BetId,
				ISNULL(rng.GameId3rd, '') AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND rng.statusID IN (111, 112, 113) THEN ISNULL(rng.ContributionRate, 0)
					ELSE rng.odds
				END AS Odds,
				0 AS MOdds,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND rng.statusID IN (111, 112, 113) THEN ISNULL(rng.BetStake, 0)
					ELSE 0
				END AS OddsSpread,
				rng.stake,
				rng.actual_stake,
				CASE
					WHEN rng.statusID IN (0, 1) THEN 0
					ELSE rng.winlost - rng.actual_stake
				END AS WinLost,
				CASE
					WHEN rng.statusID IN (0, 1) THEN 0
					ELSE - (rng.winlost - rng.actual_stake)
				END AS LicenseeWL,
				rng.playercomm,
				CASE
					WHEN rng.statusID IN (0, 1) THEN 0
					ELSE rng.comm
				END AS Comm,
				rng.status,
				0 AS SettlementStatus,
				rng.transdate,
				rng.winlostdate,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				rng.ip,
				rng.betfrom,
				0 AS LeagueId,
				0 AS LeagueGroupId,
				0 AS MatchId,
				CASE
					WHEN @Product IN ('SBC') THEN ISNULL(rng.SiteID, '')
					ELSE rng.Additional
				END AS MatchCode,
				'' AS Race,
				NULL AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				rng.TranId3rd AS BetCheck,
				rng.transdesc,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(rng.RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				rng.ExtraInfo,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(rng.JackpotInfo, '')
					ELSE ''
				END AS JackpotInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(rng.SiteID, '') AS SiteId,
				5 AS WhTicket
			FROM dbo.bettransRnG AS rng WITH (NOLOCK)
			WHERE rng.transid = @TransId
		END

		-- BettransRnG14
		IF @WhTicket = 6
		BEGIN
			INSERT INTO @Data
			(
				TransId, RefNo, CustId, Currency, Recommend, SportType, BetType, BetId, BetTeam, Hdp1,
				Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, WinLost, LicenseeWL, PlayerComm,
				Comm, Status, SettlementStatus, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom,
				LeagueId, LeagueGroupId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral,
				Placing, ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, OriginalStake, OriginalBetType, WalletType,
				RefCode, SiteId, WhTicket
			)
			SELECT
				rng14.transid,
				rng14.transid AS RefNo,
				rng14.custid,
				rng14.currency,
				rng14.recommend,
				rng14.productID AS SportType,
				rng14.gameID AS BetType,
				0 AS BetId,
				ISNULL(rng14.GameId3rd, '') AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND rng14.statusID IN (111, 112, 113) THEN ISNULL(rng14.ContributionRate, 0)
					ELSE rng14.odds
				END AS Odds,
				0 AS MOdds,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND rng14.statusID IN (111, 112, 113) THEN ISNULL(rng14.BetStake, 0)
					ELSE 0
				END AS OddsSpread,
				rng14.stake,
				rng14.actual_stake,
				CASE
					WHEN rng14.statusID IN (0, 1) THEN 0
					ELSE rng14.winlost - rng14.actual_stake
				END AS WinLost,
				CASE
					WHEN rng14.statusID IN (0, 1) THEN 0
					ELSE - (rng14.winlost - rng14.actual_stake)
				END AS LicenseeWL,
				rng14.playercomm,
				CASE
					WHEN rng14.statusID IN (0, 1) THEN 0
					ELSE rng14.comm
				END AS Comm,
				rng14.status,
				0 AS SettlementStatus,
				rng14.transdate,
				rng14.winlostdate,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				rng14.ip,
				rng14.betfrom,
				0 AS LeagueId,
				0 AS LeagueGroupId,
				0 AS MatchId,
				CASE
					WHEN @Product IN ('SBC') THEN ISNULL(rng14.SiteID, '')
					ELSE rng14.Additional
				END AS MatchCode,
				'' AS Race,
				NULL AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				rng14.TranId3rd AS BetCheck,
				rng14.transdesc,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(rng14.RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				rng14.ExtraInfo,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(rng14.JackpotInfo, '')
					ELSE ''
				END AS JackpotInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(rng14.SiteID, '') AS SiteId,
				6 AS WhTicket
			FROM dbo.bettransRnG14 AS rng14 WITH (NOLOCK)
			WHERE rng14.transid = @TransId
		END

		-- BettransRnG_bk
		IF @WhTicket = 7
		BEGIN
			INSERT INTO @Data
			(
				TransId, RefNo, CustId, Currency, Recommend, SportType, BetType, BetId, BetTeam, Hdp1,
				Hdp2, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, WinLost, LicenseeWL, PlayerComm,
				Comm, Status, SettlementStatus, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom,
				LeagueId, LeagueGroupId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral,
				Placing, ShowTime, BetCheck, TransDesc, BetdaqId, ExtraInfo, JackpotInfo, OriginalStake, OriginalBetType, WalletType,
				RefCode, SiteId, WhTicket
			)
			SELECT
				rngbk.transid,
				rngbk.transid AS RefNo,
				rngbk.custid,
				rngbk.currency,
				rngbk.recommend,
				rngbk.productID AS SportType,
				rngbk.gameID AS BetType,
				0 AS BetId,
				ISNULL(GameId3rd, '') AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND rngbk.statusID IN (111, 112, 113) THEN ISNULL(rngbk.ContributionRate, 0)
					ELSE rngbk.odds
				END AS Odds,
				0 AS MOdds,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND rngbk.statusID IN (111, 112, 113) THEN ISNULL(rngbk.BetStake, 0)
					ELSE 0
				END AS OddsSpread,
				rngbk.stake,
				rngbk.actual_stake,
				CASE
					WHEN rngbk.statusID IN (0, 1) THEN 0
					ELSE rngbk.winlost - rngbk.actual_stake
				END AS WinLost,
				CASE
					WHEN rngbk.statusID IN (0, 1) THEN 0
					ELSE - (rngbk.winlost - rngbk.actual_stake)
				END AS LicenseeWL,
				rngbk.playercomm,
				CASE
					WHEN rngbk.statusID IN (0, 1) THEN 0
					ELSE rngbk.comm
				END AS Comm,
				rngbk.status,
				0 AS SettlementStatus,
				rngbk.transdate,
				rngbk.winlostdate,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				dp.IP,
				rngbk.betfrom,
				0 AS LeagueId,
				0 AS LeagueGroupId,
				0 AS MatchId,
				CASE
					WHEN @Product IN ('SBC') THEN ISNULL(SiteID, '')
					ELSE rngbk.Additional
				END AS MatchCode,
				'' AS Race,
				NULL AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				rngbk.TranId3rd AS BetCheck,
				rngbk.transdesc,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(rngbk.RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				ExtraInfo,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(rngbk.JackpotInfo, '')
					ELSE ''
				END AS JackpotInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(SiteID, '') AS SiteId,
				7 AS WhTicket
			FROM bodb_Archive.dbo.bettransRnG_bk AS rngbk WITH (NOLOCK)
				CROSS APPLY dbo.f_IP_Decompress(rngbk.ip) AS dp
			WHERE rngbk.transid = @TransId
				 AND rngbk.custid = @CustId
				 AND rngbk.winlostdate = @WinLostDate
		END
	END

	DELETE @Data
	WHERE Currency NOT IN (SELECT DISTINCT Currency FROM @TempAg)

	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM @Data

	-- Get exchange rate
	DECLARE @ExchangeRate AS TABLE (
		ExchangeId	INT,
		FromDate	SMALLDATETIME,
		ToDate		SMALLDATETIME,
		Rate		FLOAT
	)

	IF @BaseCurrency <> ''
	BEGIN
		INSERT INTO @ExchangeRate (ExchangeId, FromDate, ToDate, Rate)
		SELECT
			e.ExchangeId,
			e.FromDate,
			e.ToDate,
			e.Rate
		FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
		WHERE EXISTS (SELECT 1 FROM @Data WHERE Currency = e.ExchangeId AND WinLostDate BETWEEN e.FromDate AND e.ToDate)
	END

	SELECT
		c.CustId,
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
		a.TransId,
		a.RefNo,
		a.BetId,
		a.TransDate,
		a.WinLostDate,
		a.SportType,
		a.BetType,
		a.BetTeam,
		a.Hdp1,
		a.Hdp2,
		a.Odds,
		a.MOdds,
		a.OddsType,
		a.OddsSpread,
		a.Status,
		a.SettlementStatus,
		a.LiveIndicator,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.Race,
		a.LeagueId,
		a.LeagueGroupId,
		a.MatchId,
		a.MatchCode,
		a.Race,
		a.EventDate,
		a.HomeId,
		a.AwayId,
		a.IsNeutral,
		a.BetStatus,
		a.Placing,
		a.ShowTime,
		a.Currency,
		CAST(a.Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Stake,
		CAST(a.Actual_Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Actual_Stake,
		CAST(a.WinLost * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS WinLost,
		CAST(a.LicenseeWL * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS LicenseeWL,
		CAST(a.PlayerComm * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS PlayerComm,
		CAST(a.Comm * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Comm,
		a.Ip,
		a.BetFrom,
		a.BetCheck,
		a.TransDesc,
		a.BetdaqId,
		a.ExtraInfo,
		a.JackpotInfo,
		a.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode,
		a.SiteId
	FROM @Data AS a
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = a.CustId
		LEFT JOIN @ExchangeRate AS e ON e.ExchangeId = a.Currency AND a.WinLostDate BETWEEN e.FromDate AND e.ToDate
	ORDER BY a.TransDate ASC

	SELECT DISTINCT
		RefNo,
		Odds,
		Stake,
		Status,
		APositionTaking,
		BetType,
		BetTeam
	FROM @Detail
END
GO
