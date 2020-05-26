/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_TxID_Mem]
	@AgentList		VARCHAR(MAX),
	@TxId			VARCHAR(100),
	@CustId			INT				= 0,
	@Username		VARCHAR(50)		= '',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(10)		= ''
AS

/*
	Created: Kos@20180604
	Task: Statement Service - Search By Licensee transaction ID
	DB: DBACC.bodb02
	Revisions:
		- 20200529@Kos: Created [#Redmine: 80941]
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

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)
	WHERE BetType NOT BETWEEN 801 AND 899

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
		Ip					NVARCHAR(15),
		BetFrom				NVARCHAR(1),
		LeagueId			INT,
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
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
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
		@OriginalCustId	INT,
		@TransId		BIGINT,
		@WinLostDate	SMALLDATETIME,
		@Recommend		INT,
		@Currency		SMALLINT,
		@BetType		SMALLINT,
		@RefCode		BIGINT		= 0,
		@ProductId		TINYINT,
		@EventType		TINYINT,
		@Product		VARCHAR(30),
		@WhTicket		TINYINT		= 0,
		@BonusTransId	BIGINT		= 0

	SET @OriginalCustId = @CustId

	IF @CustId NOT IN (-1, 0)
	BEGIN
		-- Bettrans range
		IF @WhTicket = 0
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
				@WhTicket = 2		-- bettrans
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate > @MoveBetsDay
				AND @TxId = CASE
								WHEN b.ExtraInfo LIKE '%p1%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@lt)[1]','VARCHAR(100)'), 0)
							END
		END

		-- Bettrans14 range
		IF @WhTicket = 0
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
				@WhTicket = 3		-- bettrans14
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
				AND @TxId = CASE
								WHEN b.ExtraInfo LIKE '%p1%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@lt)[1]','VARCHAR(100)'), 0)
							END
		END

		-- Bettrans_bk range
		IF @WhTicket = 0
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
				@WhTicket = 4		-- bettrans_bk
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.custid = @CustId
				AND @TxId = CASE
								WHEN b.ExtraInfo LIKE '%p1%'
									THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@lt)[1]','VARCHAR(100)'), 0)
							END
		END

		IF @WhTicket > 0
			AND NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = @Recommend AND Currency = @Currency)
		BEGIN
			SET @WhTicket = 0
		END
	END

	SET @Product = CASE
						WHEN @EventType = 0 AND @ProductId = 1 THEN 'Parlay'		-- Sportsbook Parlay
						WHEN @EventType = 1 AND @ProductId = 1 THEN 'SB'			-- Sportsbook
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
			SELECT TOP(1) @BonusTransId = b.transid
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE b.custid = @CustId
				AND b.winlostdate = @WinLostDate
				AND b.RefCode = @RefCode
				AND b.transid <> @TransId
		END
		ELSE IF @WhTicket = 4
		BEGIN
			SELECT TOP(1) @BonusTransId = b.transid
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
			WHERE b.custid = @CustId
				AND b.winlostdate = @WinLostDate
				AND b.RefCode = @RefCode
				AND b.transid <> @TransId
		END
	END

	DECLARE @IsBA BIT = 0

	IF EXISTS (SELECT TOP(1) 1 FROM bodb_Licensee.dbo.LicenseeBATransaction_active WITH (NOLOCK) WHERE transid = @TransId)
		OR EXISTS (SELECT TOP(1) 1 FROM bodb_Licensee.dbo.LicenseeBATransaction_bk WITH (NOLOCK) WHERE transid = @TransId)
	BEGIN
		SET @IsBA = 1
	END

	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

	IF @WhTicket = 2	-- Bettrans
	BEGIN
		INSERT INTO @Data
		SELECT
			CASE
				WHEN @Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS TransId,
			b.refno,
			b.custid,
			b.currency,
			b.recommend,
			CASE
				WHEN @Product IN ('SB') THEN m.sporttype
				WHEN @Product IN ('Outright') THEN l.sporttype
				ELSE 0
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			CASE
				WHEN @Product IN ('SB', 'Parlay') THEN b.betteam
				ELSE ''
			END AS BetTeam,
			CASE
				WHEN @Product IN ('SB', 'Parlay') THEN b.hdp1
				ELSE 0
			END AS Hdp1,
			CASE
				WHEN @Product IN ('SB', 'Parlay') THEN b.hdp2
				ELSE 0
			END AS Hdp2,
			CASE
				WHEN @Product IN ('SB', 'Outright') THEN b.oddstype
				ELSE 0
			END AS OddsType,
			CASE
				WHEN @Product IN ('SB', 'Outright', 'Parlay') THEN b.odds
				ELSE 0
			END AS Odds,
			CASE
				WHEN @Product IN ('SB', 'Outright', 'Parlay')  THEN b.modds 
				ELSE 0
			END AS MOdds,
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
			CASE
				WHEN @Product IN ('SB') THEN b.liveindicator
				ELSE 0
			END AS LiveIndicator,
			CASE
				WHEN @Product IN ('SB', 'Outright', 'Parlay') THEN b.livehomescore
				ELSE 0
			END AS LiveHomeScore,
			CASE
				WHEN @Product IN ('SB', 'Outright') THEN b.liveawayscore
				ELSE 0
			END AS LiveAwayScore,
			b.ip,
			b.betfrom,
			CASE
				WHEN @Product IN ('SB') THEN m.leagueid
				WHEN @Product IN ('Outright') THEN o.leagueid
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB') THEN m.matchid
				ELSE 0
			END AS MatchId,
			CASE
				WHEN @Product IN ('SB') THEN m.matchcode
				WHEN @Product IN ('Outright') THEN o.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN @Product IN ('Outright') THEN o.groupmatch
				ELSE ''
			END AS Race,
			CASE
				WHEN @Product IN ('SB') THEN m.GlobalShowTime
				ELSE b.WinLostDate
			END AS EventDate,
			CASE
				WHEN @Product IN ('SB') THEN m.homeid
				WHEN @Product IN ('Outright') THEN o.teamid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @Product IN ('SB') THEN m.awayid
				ELSE 0
			END AS AwayId,
			CASE
				WHEN @Product IN ('SB') THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			'' AS Placing,
			'' AS ShowTime,
			CASE
				WHEN @Product IN ('SB', 'Parlay') THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			CASE
				WHEN @Product IN ('SB', 'Parlay', 'Outright') THEN ISNULL(b.ExtraInfo, '')
				ELSE ''
			END AS ExtraInfo,
			CASE
				WHEN @Product IN ('SB') AND b.ExtraInfo LIKE '%p25%' THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
				ELSE 0
			END AS OriginalStake,
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
			2 AS WhTicket
		FROM dbo.bettrans AS b WITH (NOLOCK)
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON @Product IN ('SB') AND b.matchid = m.matchid
			LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON @Product IN ('Outright') AND b.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
		WHERE b.transid IN (@TransId, @BonusTransId)
	END
	ELSE IF @WhTicket = 3		-- Bettrans14 range
	BEGIN
		INSERT INTO @Data
		SELECT
			CASE
				WHEN @Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS TransId,
			b.refno,
			b.custid,
			b.currency,
			b.recommend,
			CASE
				WHEN @Product IN ('SB') THEN m.sporttype
				WHEN @Product IN ('Outright') THEN l.sporttype
				ELSE 0
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			CASE
				WHEN @Product IN ('SB', 'Parlay') THEN b.betteam
				ELSE ''
			END AS BetTeam,
			CASE
				WHEN @Product IN ('SB', 'Parlay') THEN b.hdp1
				ELSE 0
			END AS Hdp1,
			CASE
				WHEN @Product IN ('SB', 'Parlay') THEN b.hdp2
				ELSE 0
			END AS Hdp2,
			CASE
				WHEN @Product IN ('SB', 'Outright') THEN b.oddstype
				ELSE 0
			END AS OddsType,
			CASE
				WHEN @Product IN ('SB', 'Outright', 'Parlay') THEN b.odds
				ELSE 0
			END AS Odds,
			CASE
				WHEN @Product IN ('SB', 'Outright', 'Parlay')  THEN b.modds 
				ELSE 0
			END AS MOdds,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.playercomm,
			b.comm,
			b.status,
			0 AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			CASE
				WHEN @Product IN ('SB') THEN b.liveindicator
				ELSE 0
			END AS LiveIndicator,
			CASE
				WHEN @Product IN ('SB', 'Outright', 'Parlay') THEN b.livehomescore
				ELSE 0
			END AS LiveHomeScore,
			CASE
				WHEN @Product IN ('SB', 'Outright') THEN b.liveawayscore
				ELSE 0
			END AS LiveAwayScore,
			b.ip,
			b.betfrom,
			CASE
				WHEN @Product IN ('SB') THEN m.leagueid
				WHEN @Product IN ('Outright') THEN o.leagueid
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB') THEN m.matchid
				ELSE 0
			END AS MatchId,
			CASE
				WHEN @Product IN ('SB') THEN m.matchcode
				WHEN @Product IN ('Outright') THEN o.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN @Product IN ('Outright') THEN o.groupmatch
				ELSE ''
			END AS Race,
			CASE
				WHEN @Product IN ('SB') THEN m.GlobalShowTime
				ELSE b.WinLostDate
			END AS EventDate,
			CASE
				WHEN @Product IN ('SB') THEN m.homeid
				WHEN @Product IN ('Outright') THEN o.teamid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @Product IN ('SB') THEN m.awayid
				ELSE 0
			END AS AwayId,
			CASE
				WHEN @Product IN ('SB') THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			'' AS Placing,
			'' AS ShowTime,
			CASE
				WHEN @Product IN ('SB', 'Parlay') THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			CASE
				WHEN @Product IN ('SB', 'Parlay', 'Outright') THEN ISNULL(b.ExtraInfo, '')
				ELSE ''
			END AS ExtraInfo,
			CASE
				WHEN @Product IN ('SB') AND b.ExtraInfo LIKE '%p25%' THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
				ELSE 0
			END AS OriginalStake,
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
			3 AS WhTicket
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON @Product IN ('SB') AND b.matchid = m.matchid
			LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON @Product IN ('Outright') AND b.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
		WHERE b.transid IN (@TransId, @BonusTransId)
	END
	ELSE IF @WhTicket = 4		-- Bettrans_bk range
	BEGIN
		INSERT INTO @Data
		SELECT
			CASE
				WHEN @Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS TransId,
			b.refno,
			b.custid,
			b.currency,
			b.recommend,
			CASE
				WHEN @Product IN ('SB') THEN m.sporttype
				WHEN @Product IN ('Outright') THEN l.sporttype
				ELSE 0
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			CASE
				WHEN @Product IN ('SB', 'Parlay') THEN b.betteam
				ELSE ''
			END AS BetTeam,
			CASE
				WHEN @Product IN ('SB', 'Parlay') THEN b.hdp1
				ELSE 0
			END AS Hdp1,
			CASE
				WHEN @Product IN ('SB', 'Parlay') THEN b.hdp2
				ELSE 0
			END AS Hdp2,
			CASE
				WHEN @Product IN ('SB', 'Outright') THEN b.oddstype
				ELSE 0
			END AS OddsType,
			CASE
				WHEN @Product IN ('SB', 'Outright', 'Parlay') THEN b.odds
				ELSE 0
			END AS Odds,
			CASE
				WHEN @Product IN ('SB', 'Outright', 'Parlay')  THEN b.modds 
				ELSE 0
			END AS MOdds,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
				ELSE 0
			END AS OddsSpread,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.playercomm,
			b.comm,
			b.status,
			0 AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			CASE
				WHEN @Product IN ('SB') THEN b.liveindicator
				ELSE 0
			END AS LiveIndicator,
			CASE
				WHEN @Product IN ('SB', 'Outright', 'Parlay') THEN b.livehomescore
				ELSE 0
			END AS LiveHomeScore,
			CASE
				WHEN @Product IN ('SB', 'Outright') THEN b.liveawayscore
				ELSE 0
			END AS LiveAwayScore,
			b.ip,
			b.betfrom,
			CASE
				WHEN @Product IN ('SB') THEN m.leagueid
				WHEN @Product IN ('Outright') THEN o.leagueid
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB') THEN m.matchid
				ELSE 0
			END AS MatchId,
			CASE
				WHEN @Product IN ('SB') THEN m.matchcode
				WHEN @Product IN ('Outright') THEN o.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN @Product IN ('Outright') THEN o.groupmatch
				ELSE ''
			END AS Race,
			CASE
				WHEN @Product IN ('SB') THEN m.GlobalShowTime
				ELSE b.WinLostDate
			END AS EventDate,
			CASE
				WHEN @Product IN ('SB') THEN m.homeid
				WHEN @Product IN ('Outright') THEN o.teamid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @Product IN ('SB') THEN m.awayid
				ELSE 0
			END AS AwayId,
			CASE
				WHEN @Product IN ('SB') THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			'' AS Placing,
			'' AS ShowTime,
			CASE
				WHEN @Product IN ('SB', 'Parlay') THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			CASE
				WHEN @Product IN ('SB', 'Parlay', 'Outright') THEN ISNULL(b.ExtraInfo, '')
				ELSE ''
			END AS ExtraInfo,
			CASE
				WHEN @Product IN ('SB') AND b.ExtraInfo LIKE '%p25%' THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
				ELSE 0
			END AS OriginalStake,
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
			4 AS WhTicket
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON @Product IN ('SB') AND b.matchid = m.matchid
			LEFT JOIN bodb_Archive.dbo.Outright_bk AS o WITH (NOLOCK) ON @Product IN ('Outright') AND b.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
		WHERE b.transid IN (@TransId, @BonusTransId)
	END

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Display Cash/Bonus text for ticket from multiple wallets
	UPDATE @Data
	SET RefCode = 0
	WHERE RefCode <> 0

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
		ExchangeDate	SMALLDATETIME,
		ExchangeId		INT,
		Rate			FLOAT
	)

	IF @BaseCurrency <> ''
	BEGIN
		INSERT INTO @ExchangeRate
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
				ELSE 1
			END AS Rate
		FROM Lrf_f_GetExchangeDaily(@ExFromDate, @ExToDate) AS e
		WHERE EXISTS (SELECT 1 FROM @Data WHERE Currency = e.ExchangeId AND WinLostDate = e.exchangedate)
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
		a.Stake * ISNULL(e.Rate, 1) AS Stake,
		a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
		a.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		a.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
		a.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		a.Comm * ISNULL(e.Rate, 1) AS Comm,
		a.Ip,
		a.BetFrom,
		a.BetCheck,
		a.TransDesc,
		a.BetdaqId,
		a.ExtraInfo,
		a.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode
	FROM @Data AS a
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = a.CustId
		LEFT JOIN @ExchangeRate AS e
			ON e.ExchangeDate = a.WinLostDate AND e.ExchangeId = a.Currency
	ORDER BY a.TransDate ASC

	SELECT DISTINCT * FROM @Detail
END
GO
