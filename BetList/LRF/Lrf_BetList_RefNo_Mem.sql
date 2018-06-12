/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_BetList_RefNo_Mem]
	@AgentList		VARCHAR(MAX),
	@RefNo			BIGINT,
	@CustId			INT				= 0,
	@Username		VARCHAR(50)		= '',
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(10)		= ''
AS

/*
	Created: Kos@20180604
	Task: Betting Ticket Center - Search By RefNo
	DB: DBACC.bodb02
	Revisions:
		- 20180604@Kos: Created [#Redmine: 80941]
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
	DECLARE @SportBettype TABLE ( ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)
	WHERE BetType NOT IN (903, 904, 913, 914)
		AND BetType NOT BETWEEN 801 AND 899

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

	DECLARE
		@TransId		BIGINT,
		@WinLostDate	SMALLDATETIME,
		@BetType		SMALLINT,
		@ProductId		TINYINT,
		@EventType		TINYINT,
		@WhTicket		TINYINT	= 0

	IF @CustId <> -1
	BEGIN
		-- Bettrans range
		IF @WhTicket = 0
		BEGIN
			SELECT TOP(1)
				@TransId = b.transid,
				@CustId = b.custid,
				@WinLostDate = b.winlostdate,
				@BetType = b.bettype,
				@ProductId = s.ProductID,
				@EventType = s.EventType,
				@WhTicket = 2		-- bettrans
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.transid = @RefNo
				AND (b.custid = @CustId OR @CustId = 0)
				AND EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.recommend)
		END

		-- Bettrans14 range
		IF @WhTicket = 0
		BEGIN
			SELECT TOP(1)
				@TransId = b.transid,
				@CustId = b.custid,
				@WinLostDate = b.winlostdate,
				@BetType = b.bettype,
				@ProductId = s.ProductID,
				@EventType = s.EventType,
				@WhTicket = 3		-- bettrans14
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.transid = @RefNo
				AND (b.custid = @CustId OR @CustId = 0)
				AND EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.recommend)
		END

		-- Bettrans_bk range
		IF @WhTicket = 0
		BEGIN
			SELECT TOP(1)
				@TransId = b.transid,
				@CustId = b.custid,
				@WinLostDate = b.winlostdate,
				@BetType = b.bettype,
				@ProductId = s.ProductID,
				@EventType = s.EventType,
				@WhTicket = 4		-- bettrans_bk
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			WHERE b.transid = @RefNo
				AND (b.custid = @CustId OR @CustId = 0)
				AND EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.recommend)
		END
	END

	DECLARE @Data AS TABLE (
		TransId			BIGINT,
		RefNo			BIGINT,
		BetId			BIGINT,
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		SportType		INT,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		MOdds			MONEY,
		OddsType		TINYINT,
		OddsSpread		MONEY,
		Status			NVARCHAR(10),
		StatusId		TINYINT,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Race			NVARCHAR(20),
		LeagueId		INT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		IsNeutral		BIT,
		BetStatus		NVARCHAR(50),
		ShowTime		NVARCHAR(50),
		Currency		TINYINT,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		PlayerComm		MONEY,
		Comm			MONEY,
		Ip				NVARCHAR(15),
		BetFrom			NVARCHAR(1),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		WalletType		TINYINT,
		RefCode			BIGINT
	)

	IF @WhTicket = 2	-- Bettrans
	BEGIN
		-- Sportbooks (EventType = 1)
		IF @EventType = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0),
				b.transdate,
				b.winlostdate,
				m.sporttype,
				b.bettype,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.oddstype,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				b.status,
				b.statusID,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS Race,
				m.leagueid,
				m.matchid,
				m.matchcode,
				m.homeid,
				m.awayid,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.betstatus,
				'' AS ShowTime,
				b.currency,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.ip,
				b.betfrom,
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
				ISNULL(b.RefCode, 0) AS RefCode
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.transid = @TransId

			-- Get more info for BetTrade tickets
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 901)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.Stake = ob.stake,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.BetId = ob.bettype
				FROM @Data AS b
					INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.SportType = 1 AND b.BetType = 901
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 902)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.Stake = ob.stake,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.Comm = ISNULL(cb.awinlost, 0),
					b.BetId = ob.bettype
				FROM @Data AS b
					INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
					LEFT JOIN dbo.bettrans AS cb WITH (NOLOCK)
						ON b.RefNo = cb.RefNo
						AND cb.BetType = 903
						AND cb.custid = @CustId
						AND cb.winlostdate = @WinLostDate
				WHERE b.SportType = 1 AND b.BetType = 902
			END

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM @Data AS b
					INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid,
					b.Stake = cob.stake,
					b.Comm = ISNULL(cb.AWinLost, 0)
				FROM @Data AS b
					INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN dbo.bettrans AS cb WITH (NOLOCK)
						ON b.RefNo = cb.RefNo
						AND cb.BetType = 913
						AND cb.custid = @CustId
						AND cb.winlostdate = @WinLostDate
				WHERE b.BetType = 912
			END
		END

		-- Mix Parlay, System Parlay (Sportsbook)
		IF @BetType IN (9, 29)
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.betid, 0) = 0 THEN b.transid
							ELSE b.betid
						END
				END AS TransId,
				b.refno,
				ISNULL(b.betid, 0),
				b.transdate,
				b.winlostdate,
				0 AS SportType,
				b.bettype,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS OddsType,
				0 AS OddsSpread,
				b.status,
				b.statusID,
				0 AS LiveIndicator,
				b.livehomescore,
				0 AS LiveAwayScore,
				'' AS Race,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				0 AS HomeId,
				0 AS AwayId,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS BetStatus,
				'' AS ShowTime,
				b.currency,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.ip,
				b.betfrom,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE b.transid = @TransId
		END

		-- Outright
		IF @BetType = 10
		BEGIN
			INSERT INTO @Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0),
				b.transdate,
				b.winlostdate,
				l.sporttype,
				b.bettype,
				'' AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				b.odds,
				b.modds,
				0 AS OddsType,
				0 AS OddsSpread,
				b.status,
				b.statusID,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				o.groupmatch AS Race,
				o.leagueid,
				o.orid AS MatchId,
				o.matchcode,
				o.teamid AS HomeId,
				0 AS AwayId,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS BetStatus,
				'' AS ShowTime,
				b.currency,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.ip,
				b.betfrom,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			WHERE b.transid = @TransId
		END

		-- Get related Bonus/Cash tickets
		IF EXISTS ( SELECT 1 FROM @Data WHERE RefCode <> 0 )
		BEGIN
			INSERT INTO @Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0),
				b.transdate,
				b.winlostdate,
				m.sporttype,
				b.bettype,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.oddstype,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				b.status,
				b.statusID,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS Race,
				m.leagueid,
				m.matchid,
				m.matchcode,
				m.homeid,
				m.awayid,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.betstatus,
				'' AS ShowTime,
				b.currency,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.ip,
				b.betfrom,
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
				ISNULL(b.RefCode, 0) AS RefCode
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.custid = @CustId
				AND b.winlostdate = @WinLostDate
				AND EXISTS (SELECT 1 FROM @Data AS d WHERE d.RefCode = b.RefCode AND d.TransId <> b.transid)
		END
	END
	ELSE IF @WhTicket = 3		-- Bettrans14 range
	BEGIN
		-- Sportbooks (EventType = 1)
		IF @EventType = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0),
				b.transdate,
				b.winlostdate,
				m.sporttype,
				b.bettype,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.oddstype,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				b.status,
				b.statusID,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS Race,
				m.leagueid,
				m.matchid,
				m.matchcode,
				m.homeid,
				m.awayid,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.betstatus,
				'' AS ShowTime,
				b.currency,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.ip,
				b.betfrom,
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
				ISNULL(b.RefCode, 0) AS RefCode
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.transid = @TransId

			-- Get more info for BetTrade tickets
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 901)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.Stake = ob.stake,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.BetId = ob.bettype
				FROM @Data AS b
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.SportType = 1 AND b.BetType = 901
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 902)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.Stake = ob.stake,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.Comm = ISNULL(cb.awinlost, 0),
					b.BetId = ob.bettype
				FROM @Data AS b
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
					LEFT JOIN dbo.bettrans14 AS cb WITH (NOLOCK)
						ON b.RefNo = cb.RefNo
						AND cb.BetType = 903
						AND cb.custid = @CustId
						AND cb.winlostdate = @WinLostDate
				WHERE b.SportType = 1 AND b.BetType = 902
			END

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM @Data AS b
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid,
					b.Stake = cob.stake,
					b.Comm = ISNULL(cb.AWinLost, 0)
				FROM @Data AS b
					INNER JOIN dbo.bettrans14 AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN dbo.bettrans14 AS cb WITH (NOLOCK)
						ON b.RefNo = cb.refno
						AND cb.BetType = 913
						AND cb.custid = @CustId
						AND cb.winlostdate = @WinLostDate
				WHERE b.BetType = 912
			END
		END

		-- Mix Parlay, System Parlay (Sportsbook)
		IF @BetType IN (9, 29)
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.betid, 0) = 0 THEN b.transid
							ELSE b.betid
						END
				END AS TransId,
				b.refno,
				ISNULL(b.betid, 0),
				b.transdate,
				b.winlostdate,
				0 AS SportType,
				b.bettype,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS OddsType,
				0 AS OddsSpread,
				b.status,
				b.statusID,
				0 AS LiveIndicator,
				b.livehomescore,
				0 AS LiveAwayScore,
				'' AS Race,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				0 AS HomeId,
				0 AS AwayId,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS BetStatus,
				'' AS ShowTime,
				b.currency,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.ip,
				b.betfrom,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE b.transid = @TransId
		END

		-- Outright
		IF @BetType = 10
		BEGIN
			INSERT INTO @Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0),
				b.transdate,
				b.winlostdate,
				l.sporttype,
				b.bettype,
				'' AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				b.odds,
				b.modds,
				0 AS OddsType,
				0 AS OddsSpread,
				b.status,
				b.statusID,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				o.groupmatch AS Race,
				o.leagueid,
				o.orid AS MatchId,
				o.matchcode,
				o.teamid AS HomeId,
				0 AS AwayId,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS BetStatus,
				'' AS ShowTime,
				b.currency,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.ip,
				b.betfrom,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			WHERE b.transid = @TransId
		END

		-- Get related Bonus/Cash tickets
		IF EXISTS ( SELECT 1 FROM @Data WHERE RefCode <> 0 )
		BEGIN
			INSERT INTO @Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0),
				b.transdate,
				b.winlostdate,
				m.sporttype,
				b.bettype,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.oddstype,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				b.status,
				b.statusID,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS Race,
				m.leagueid,
				m.matchid,
				m.matchcode,
				m.homeid,
				m.awayid,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.betstatus,
				'' AS ShowTime,
				b.currency,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.ip,
				b.betfrom,
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
				ISNULL(b.RefCode, 0) AS RefCode
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.custid = @CustId
				AND b.winlostdate = @WinLostDate
				AND EXISTS (SELECT 1 FROM @Data AS d WHERE d.RefCode = b.RefCode AND d.TransId <> b.transid)
		END
	END
	ELSE IF @WhTicket = 4		-- Bettrans_bk range
	BEGIN
		-- Sportbooks (EventType = 1)
		IF @EventType = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0),
				b.transdate,
				b.winlostdate,
				m.sporttype,
				b.bettype,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.oddstype,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				b.status,
				b.statusID,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS Race,
				m.leagueid,
				m.matchid,
				m.matchcode,
				m.homeid,
				m.awayid,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.betstatus,
				'' AS ShowTime,
				b.currency,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.ip,
				b.betfrom,
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
				ISNULL(b.RefCode, 0) AS RefCode
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.transid = @TransId

			-- Get more info for BetTrade tickets
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 901)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.Stake = ob.stake,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.BetId = ob.bettype
				FROM @Data AS b
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.SportType = 1 AND b.BetType = 901
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 902)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.Stake = ob.stake,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.Comm = ISNULL(cb.awinlost, 0),
					b.BetId = ob.bettype
				FROM @Data AS b
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
					LEFT JOIN bodb_Archive.dbo.bettrans_bk AS cb WITH (NOLOCK)
						ON b.RefNo = cb.refno
						AND cb.bettype = 903
						AND cb.custid = @CustId
						AND cb.winlostdate = @WinLostDate
				WHERE b.SportType = 1 AND b.BetType = 902
			END

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM @Data AS b
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid,
					b.Stake = cob.stake,
					b.Comm = ISNULL(cb.AWinLost, 0)
				FROM @Data AS b
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN bodb_Archive.dbo.bettrans_bk AS cb WITH (NOLOCK)
						ON b.RefNo = cb.refno
						AND cb.bettype = 913
						AND cb.custid = @CustId
						AND cb.winlostdate = @WinLostDate
				WHERE b.BetType = 912
			END
		END

		-- Mix Parlay, System Parlay (Sportsbook)
		IF @BetType IN (9, 29)
		BEGIN
			INSERT INTO @Data
			SELECT
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE
						CASE
							WHEN ISNULL(b.betid, 0) = 0 THEN b.transid
							ELSE b.betid
						END
				END AS TransId,
				b.refno,
				ISNULL(b.betid, 0),
				b.transdate,
				b.winlostdate,
				0 AS SportType,
				b.bettype,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS OddsType,
				0 AS OddsSpread,
				b.status,
				b.statusID,
				0 AS LiveIndicator,
				b.livehomescore,
				0 AS LiveAwayScore,
				'' AS Race,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				0 AS HomeId,
				0 AS AwayId,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS BetStatus,
				'' AS ShowTime,
				b.currency,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.ip,
				b.betfrom,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			WHERE b.transid = @TransId
		END

		-- Outright
		IF @BetType = 10
		BEGIN
			-- Outright
			INSERT INTO @Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0),
				b.transdate,
				b.winlostdate,
				l.sporttype,
				b.bettype,
				'' AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				b.odds,
				b.modds,
				0 AS OddsType,
				0 AS OddsSpread,
				b.status,
				b.statusID,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				o.groupmatch AS Race,
				o.leagueid,
				o.orid AS MatchId,
				o.matchcode,
				o.teamid AS HomeId,
				0 AS AwayId,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS BetStatus,
				'' AS ShowTime,
				b.currency,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.ip,
				b.betfrom,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.Outright_bk AS o WITH (NOLOCK) ON b.matchid = o.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			WHERE b.transid = @TransId AND b.bettype = 10
		END

		-- Get related Bonus/Cash tickets
		IF EXISTS ( SELECT 1 FROM @Data WHERE RefCode <> 0 )
		BEGIN
			INSERT INTO @Data
			SELECT
				b.transid,
				b.refno,
				ISNULL(b.betid, 0),
				b.transdate,
				b.winlostdate,
				m.sporttype,
				b.bettype,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.oddstype,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				b.status,
				b.statusID,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS Race,
				m.leagueid,
				m.matchid,
				m.matchcode,
				m.homeid,
				m.awayid,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.betstatus,
				'' AS ShowTime,
				b.currency,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.ip,
				b.betfrom,
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
				ISNULL(b.RefCode, 0) AS RefCode
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.custid = @CustId
				AND b.winlostdate = @WinLostDate
				AND EXISTS (SELECT 1 FROM @Data AS d WHERE d.RefCode = b.RefCode AND d.TransId <> b.transid)
		END
	END

	DELETE @Data
	WHERE Currency NOT IN (SELECT DISTINCT Currency FROM @TempAg)

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Display Cash/Bonus text for ticket from multiple wallets
	UPDATE @Data
	SET RefCode = 0
	WHERE RefCode <> 0

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
				ELSE 1
			END AS Rate
		FROM Lrf_f_GetExchangeDaily(@ExFromDate, @ExToDate) AS e
		WHERE EXISTS (SELECT 1 FROM @Data WHERE Currency = e.ExchangeId AND WinLostDate = e.exchangedate)
	END

	SELECT
		@CustId AS CustId,
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
		a.StatusId,
		a.LiveIndicator,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.Race,
		a.LeagueId,
		a.MatchId,
		a.MatchCode,
		a.HomeId,
		a.AwayId,
		a.IsNeutral,
		a.BetStatus,
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
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = @CustId
		LEFT JOIN @ExchangeRate AS e
			ON e.ExchangeDate = a.WinLostDate AND e.ExchangeId = a.Currency
END




GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_RefNo_Mem] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_RefNo_Mem] TO [vnteam]
GO
