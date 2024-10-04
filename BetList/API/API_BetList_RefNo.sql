/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[API_BetList_RefNo]
	@RefNo			BIGINT,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@ErrCode		INT				= 0		OUTPUT,
	@ErrMsg			VARCHAR(100)	= ''	OUTPUT
AS

/*
	Created: Kos@20240725
	Task: API - Search By RefNo
	DB: DBACC.bodb02
	Revisions:
		- 20240725@Kos: Created [#Redmine: 207623]
		- 20240725@Kos: Return additional column [#Redmine: 207623]
		- 20241004@Kos: Return additional column PlayerSiteId [#Redmine: 207623]
*/

BEGIN
	SET NOCOUNT ON

	-- Get SportBetTypeMatrix
	DECLARE @SportBettype TABLE ( ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, RefTable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)
	WHERE BetType NOT IN (71, 72, 901, 902, 903, 904, 913, 914, 999)
		AND BetType NOT BETWEEN 801 AND 899

	DECLARE @Data TABLE (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Currency			SMALLINT,
		Recommend			INT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(200),
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
		BetCheck			NVARCHAR(2000),
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
		@CustId				INT,
		@Username			VARCHAR(50),
		@Nickname			VARCHAR(50),
		@PlayerSiteId		INT,
		@TransId			BIGINT,
		@WinLostDate		SMALLDATETIME,
		@Recommend			INT,
		@Currency			SMALLINT,
		@BetType			SMALLINT,
		@ProductId			TINYINT,
		@EventType			TINYINT,
		@RefTable			TINYINT,
		@Product			VARCHAR(30),
		@WhTicket			TINYINT		= 0,
		@MainCustId			INT			= 0,
		@IsDeposit			BIT,
		@SpecialPlatform	TINYINT		= 0

	SELECT TOP(1)
		@TransId = b.transid,
		@CustId = b.custid,
		@WinLostDate = b.winlostdate,
		@Recommend = b.recommend,
		@Currency = b.currency,
		@BetType = b.bettype,
		@ProductId = s.ProductID,
		@EventType = s.EventType,
		@RefTable = s.RefTable,
		@WhTicket = 2		-- bettrans
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
	WHERE b.transid = @RefNo
		AND b.winlostdate > @MoveBetsDay

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
			@ProductId = s.ProductID,
			@EventType = s.EventType,
			@RefTable = s.RefTable,
			@WhTicket = 3		-- bettrans14
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
		WHERE b.transid = @RefNo
			AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
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
			@ProductId = s.ProductID,
			@EventType = s.EventType,
			@RefTable = s.RefTable,
			@WhTicket = 4		-- bettrans_bk
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
		WHERE b.transid = @RefNo
	END

	IF @WhTicket > 0
	BEGIN
		IF EXISTS ( SELECT 1
					FROM dbo.Customer WITH (NOLOCK)
					WHERE custid = @CustId AND CHARINDEX('SabaCoins$', username2) > 0 )		-- Shadow account
		BEGIN
			SELECT @MainCustId = CASE
									WHEN CHARINDEX('SabaCoins$', username2) > 0
										THEN CAST(SUBSTRING(username2, CHARINDEX('SabaCoins$', username2) + LEN('SabaCoins$'), LEN(username2)) AS INT)
									ELSE 0
								END
			FROM dbo.Customer WITH (NOLOCK)
			WHERE custid = @CustId

			SELECT
				@IsDeposit = s.isDeposit,
				@SpecialPlatform = s.SpecialPlatfrom
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN dbo.Site AS s WITH (NOLOCK) ON s.site = c.Site
			WHERE c.custid = @MainCustId
		END
		ELSE
		BEGIN
			SELECT
				@IsDeposit = s.isDeposit,
				@SpecialPlatform = s.SpecialPlatfrom
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN dbo.Site AS s WITH (NOLOCK) ON s.site = c.Site
			WHERE c.custid = @CustId
		END

		IF ISNULL(@IsDeposit, 0) <> 1
		BEGIN
			SELECT
				@WhTicket = 0,
				@ErrCode = 101,
				@ErrMsg = 'You have no permission to check the ticket'
		END
	END

	SET @Product = CASE
						WHEN @EventType = 0 AND @ProductId = 1 THEN 'Parlay'		-- Sportsbook Parlay
						WHEN @EventType = 1 AND @ProductId = 1 THEN 'SB'			-- Sportsbook
						WHEN @EventType = 2 AND @ProductId = 1 THEN 'Outright'
						ELSE 'Unknown'
					END

	DECLARE @IsBA BIT = 0

	IF EXISTS (SELECT TOP(1) 1 FROM bodb_Licensee.dbo.LicenseeBATransaction_active WITH (NOLOCK) WHERE transid = @TransId)
		OR EXISTS (SELECT TOP(1) 1 FROM bodb_Licensee.dbo.LicenseeBATransaction_bk WITH (NOLOCK) WHERE transid = @TransId)
	BEGIN
		SET @IsBA = 1
	END

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
				WHEN @Product IN ('Outright') THEN l.sporttype
				WHEN @EventType = 1 THEN m.sporttype
				ELSE b.matchid
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.modds,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			b.stake,
			b.actual_stake,
			b.winlost - b.actual_stake AS WinLost,
			CASE
				WHEN @IsBA = 1 THEN 0
				ELSE - (b.winlost - b.actual_stake)
			END AS LicenseeWL,
			b.PlayerComm,
			b.Comm,
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
				WHEN @Product IN ('Outright') THEN o.leagueid
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB') THEN le.LeagueGroupID
				ELSE 0
			END AS LeagueGroupId,
			b.matchid,
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
				ELSE b.WinLostDate
			END AS EventDate,
			CASE
				WHEN @EventType = 1 THEN m.homeid
				WHEN @Product IN ('Outright') THEN o.teamid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @EventType = 1 THEN m.awayid
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
			'' AS ShowTime,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betcheck, '')
				WHEN @EventType = 0 AND @RefTable = 0 THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @EventType = 1 THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			'' AS JackpotInfo,
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
			'' AS SiteId,
			2 AS WhTicket
		FROM dbo.bettrans AS b WITH (NOLOCK)
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON @EventType = 1 AND b.matchid = m.matchid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON @Product IN ('SB') AND le.leagueid = m.leagueid
			LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON @Product IN ('Outright') AND b.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
		WHERE b.transid = @TransId
	END
	
	IF @WhTicket = 3		-- Bettrans14 range
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
				WHEN @Product IN ('Outright') THEN l.sporttype
				WHEN @EventType = 1 THEN m.sporttype
				ELSE b.matchid
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.modds,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			CASE
				WHEN @IsBA = 1 THEN 0
				ELSE - (b.winlost - b.actual_stake)
			END AS LicenseeWL,
			b.playercomm,
			b.comm,
			b.status,
			0 AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.betfrom,
			CASE
				WHEN @EventType = 1 THEN m.leagueid
				WHEN @Product IN ('Outright') THEN o.leagueid
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB') THEN le.LeagueGroupID
				ELSE 0
			END AS LeagueGroupId,
			b.matchid,
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
				ELSE b.WinLostDate
			END AS EventDate,
			CASE
				WHEN @EventType = 1 THEN m.homeid
				WHEN @Product IN ('Outright') THEN o.teamid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @EventType = 1 THEN m.awayid
				ELSE 0
			END AS AwayId,
			CASE
				WHEN @EventType = 1THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN @EventType = 1 THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			'' AS Placing,
			'' AS ShowTime,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betcheck, '')
				WHEN @EventType = 0 AND @RefTable = 0 THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @EventType = 1 THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			'' AS JackpotInfo,
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
			'' AS SiteId,
			3 AS WhTicket
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON @EventType = 1 AND b.matchid = m.matchid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON @Product IN ('SB') AND le.leagueid = m.leagueid
			LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON @Product IN ('Outright') AND b.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
		WHERE b.transid = @TransId
	END
	
	IF @WhTicket = 4		-- Bettrans_bk range
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
				WHEN @Product IN ('Outright') THEN l.sporttype
				WHEN @EventType = 1 THEN m.sporttype
				ELSE b.matchid
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.modds,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			CASE
				WHEN @IsBA = 1 THEN 0
				ELSE - (b.winlost - b.actual_stake)
			END AS LicenseeWL,
			b.playercomm,
			b.comm,
			b.status,
			0 AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.betfrom,
			CASE
				WHEN @EventType = 1 THEN m.leagueid
				WHEN @Product IN ('Outright') THEN o.leagueid
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB') THEN le.LeagueGroupID
				ELSE 0
			END AS LeagueGroupId,
			b.matchid,
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
				ELSE b.WinLostDate
			END AS EventDate,
			CASE
				WHEN @EventType = 1 THEN m.homeid
				WHEN @Product IN ('Outright') THEN o.teamid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @EventType = 1 THEN m.awayid
				ELSE 0
			END AS AwayId,
			CASE
				WHEN @EventType = 1THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN @EventType = 1 THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			'' AS Placing,
			'' AS ShowTime,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betcheck, '')
				WHEN @EventType = 0 AND @RefTable = 0 THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @EventType = 1 THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			'' AS JackpotInfo,
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
			'' AS SiteId,
			4 AS WhTicket
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON @EventType = 1 AND b.matchid = m.matchid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON @Product IN ('SB') AND le.leagueid = m.leagueid
			LEFT JOIN bodb_Archive.dbo.Outright_bk AS o WITH (NOLOCK) ON @Product IN ('Outright') AND b.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
			CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
		WHERE b.transid = @TransId
	END

	IF EXISTS (SELECT 1 FROM @Data)
	BEGIN
		SELECT
			@Username = username,
			@Nickname = SUBSTRING(username2, CHARINDEX('$', username2) + 1, LEN(username2) - CHARINDEX('$', username2)),
			@PlayerSiteId = s.siteid
		FROM dbo.Customer AS c WITH (NOLOCK)
			INNER JOIN dbo.Site AS s WITH (NOLOCK) ON s.site = c.site
		WHERE c.custid = CASE
							WHEN @MainCustId <> 0 THEN @MainCustId		-- shadow account
							ELSE @CustId
						END
	END

	SELECT
		a.CustId,
		a.Recommend,
		@Username AS Username,
		@Nickname AS NickName,
		@PlayerSiteId AS PlayerSiteId,
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
		a.Stake,
		a.Actual_Stake,
		a.WinLost,
		a.LicenseeWL,
		a.PlayerComm,
		a.Comm,
		a.Ip,
		a.BetFrom,
		a.BetCheck,
		a.TransDesc,
		a.BetdaqId,
		a.ExtraInfo,
		a.JackpotInfo,
		a.OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode,
		a.SiteId,
		@SpecialPlatform AS SpecialPlatform
	FROM @Data AS a
	ORDER BY a.TransDate ASC

	SELECT DISTINCT * FROM @Detail
END
GO
