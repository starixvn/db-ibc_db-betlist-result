/*<info serverAlias="DBSID-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Lrf_BetList_TxID_Mem]
	@AgentList		VARCHAR(MAX),
	@TxId			VARCHAR(100),
	@CustId			INT				= 0,
	@Username		VARCHAR(50)		= '',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20220824@Kos
	Task: LAP - Statement Service - Search By Licensee transaction ID
	DB: DBSID.bodb02

	Revisions:
		- 20220824@Kos: Scale out DBTRANS [Redmine: #175297]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
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
		FROM CustDB.dbo.Customer AS c WITH (NOLOCK)
		WHERE EXISTS (SELECT 1 FROM @TempAg WHERE CustId = c.recommend)
			AND c.username = @Username

		IF @CustId = -1
		BEGIN
			SELECT @CustId = custid
			FROM CustDB.dbo.Customer AS c WITH (NOLOCK)
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
			CASE
				WHEN @Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS TransId,
			b.refno,
			b.custid,
			b.currency,
			b.recommend,
			CASE
				WHEN @Product IN ('Keno', 'Lottery', 'TG', 'SLT', 'H5LG', 'TIP') THEN b.matchid
				WHEN @EventType = 1 THEN m.sporttype
				WHEN @EventType = 5 THEN m3rd.SportType
				WHEN @Product IN ('Outright') THEN l.sporttype
				WHEN @EventType = 3 THEN l.sporttype
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
				WHEN @Product = 'Parlay' AND b.OddsSpread = 3 THEN ISNULL(b.transdesc, '')
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
								INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId)
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
		IF @WhTicket = 0
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
				transid,
				transid AS RefNo,
				custid,
				currency,
				recommend,
				productID AS SportType,
				gameID AS BetType,
				0 AS BetId,
				ISNULL(GameId3rd, '') AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND statusID IN (111, 112, 113) THEN ISNULL(ContributionRate, 0)
					ELSE odds
				END AS Odds,
					0 AS MOdds,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND statusID IN (111, 112, 113) THEN ISNULL(BetStake, 0)
					ELSE 0
				END AS OddsSpread,
				stake,
				actual_stake,
				CASE
					WHEN statusID IN (0, 1) THEN 0
					ELSE winlost - actual_stake
				END AS WinLost,
				CASE
					WHEN statusID IN (0, 1) THEN 0
					ELSE - (winlost - actual_stake)
				END AS LicenseeWL,
				playercomm,
				CASE
					WHEN statusID IN (0, 1) THEN 0
					ELSE comm
				END AS Comm,
				status,
				0 AS SettlementStatus,
				transdate,
				winlostdate,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				ip,
				betfrom,
				0 AS LeagueId,
				0 AS LeagueGroupId,
				0 AS MatchId,
				CASE
					WHEN @Product IN ('SBC') THEN ISNULL(SiteID, '')
					ELSE Additional
				END AS MatchCode,
				'' AS Race,
				NULL AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				TranId3rd AS BetCheck,
				transdesc,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				ExtraInfo,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(JackpotInfo, '')
					ELSE ''
				END AS JackpotInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(SiteID, '') AS SiteId,
				5 AS WhTicket
			FROM dbo.bettransRnG WITH (NOLOCK)
			WHERE transid = @TransId
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
		FROM dbo.SiteDB_Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
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
		INNER JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON c.custid = a.CustId
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
