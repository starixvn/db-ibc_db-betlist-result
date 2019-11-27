/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_Monitor_BetList]
	@CustId				INT,
	@RoleId				TINYINT,
	@SubAccId			INT				= 0,
	@IsAllDownline		BIT				= 0,
	@SportTypeGroup		TINYINT			= 0,
	@StakeList			VARCHAR(MAX),
	@Market				VARCHAR(10)		= '',
	@LeagueList			VARCHAR(MAX)	= '',
	@MatchList			VARCHAR(MAX)	= '',
	@BetTypeGroupList	VARCHAR(MAX)	= '',
	@PageSize			INT,
	@MinTransId			BIGINT OUTPUT
AS

/*
	Created: Kos@20190405
	Task: Bet List of CN88 Wager Monitoring
	DB: DB042.bodb02

	Param's Explanation:
		- @RoleId: role ID
			- 2: Agent
			- 3: Master
			- 4: Super
		- @SubAccId: Sub Account ID
		- @IsAllDownline:
			- 0: Not view all downline of CustId
			- 1: View all downline of CustId
		- @StakeList: XML format (0: =, 1: >, 2: <)
			- All Sports: '<ROOT><SportTypeGroup Id="0" Condition="0" Stake="50"/></ROOT>'
			- Per Sports: '<ROOT>
							<SportTypeGroup Id="1" Condition="0" Stake="50"/>
							<SportTypeGroup Id="2" Condition="1" Stake="30"/>
							<SportTypeGroup Id="3" Condition="2" Stake="100"/>
						</ROOT>'
		- @Market:
			- 1: In-Play
			- 2: Today
			- 3: Early
		- @LeagueList: 
			- All leagues: ''
			- Specific leagues: '123,456,789' (LeagueId1,LeagueId2,LeagueId3, ...)
		- @MatchList: 
			- All matches: ''
			- Specific matches: '123,456,789' (MatchId1,MatchId2,MatchId3, ...)
		- @BetTypeList: 
			- All bet types: ''
			- Specific bettypes: '1,3,5,7' (BetType1,BetType2,BetType3, ...)

	Revisions:
		- 20190405@Kos: Create new [Redmine: #111245]
		- 20190606@Kos: Remove unused code [Redmine: #114242]
		- 20190716@Kos: Support subaccount permission [Redmine: #116825]
					- Add new param @SubAccId, @IsAllDownline
		- 20191127@Kos: Hotfix - Change oddsspread data type from SMALLMONEY to MONEY [Redmine: #124483]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @MemBetTicket TABLE (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Username			NVARCHAR(50),
		DownlineCustId		INT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsType			TINYINT,
		Odds				MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		Status				NVARCHAR(10),
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		APositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		SPositionTaking		SMALLMONEY,
		TPositionTaking		SMALLMONEY,
		PlayerDiscount		SMALLMONEY,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					NVARCHAR(15),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		ExtraInfo			VARCHAR(1000),
		MatchId				INT,
		SportType			SMALLINT,
		SportTypeGroup		SMALLINT,
		LeagueId			INT,
		EventDate			SMALLDATETIME,
		EventStatus			NVARCHAR(50),
		ShowTime			DATETIME,
		EventType			TINYINT,
		Market				TINYINT
	);

	IF @MinTransId > 0
	BEGIN
		IF @RoleId = 2		-- Agent
		BEGIN
			INSERT INTO @MemBetTicket (
				TransId,
				RefNo,
				CustId,
				Username,
				DownlineCustId,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsType,
				Odds,
				Stake,
				Actual_Stake,
				Status,
				TransDate,
				WinLostDate,
				APositionTaking,
				MPositionTaking,
				SPositionTaking,
				TPositionTaking,
				PlayerDiscount,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				BetCheck,
				TransDesc,
				OddsSpread,
				ExtraInfo,
				MatchId)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.username,
				b.custid AS DownlineCustId,
				b.bettype,
				ISNULL(b.betid, 0) AS BetId,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.status,
				b.transdate,
				b.winlostdate,
				b.APositiontaking,
				b.MPositiontaking,
				b.SPositiontaking,
				b.TPositiontaking,
				b.playerdiscount,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				b.matchid
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE b.recommend = @CustId
				AND b.statusID IN (0, 1)
				AND b.transid > @MinTransId
		END
		ELSE IF @RoleId = 3		-- Master
		BEGIN
			INSERT INTO @MemBetTicket (
				TransId,
				RefNo,
				CustId,
				Username,
				DownlineCustId,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsType,
				Odds,
				Stake,
				Actual_Stake,
				Status,
				TransDate,
				WinLostDate,
				APositionTaking,
				MPositionTaking,
				SPositionTaking,
				TPositionTaking,
				PlayerDiscount,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				BetCheck,
				TransDesc,
				OddsSpread,
				ExtraInfo,
				MatchId)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.username,
				b.recommend AS DownlineCustId,
				b.bettype,
				ISNULL(b.betid, 0) AS BetId,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.status,
				b.transdate,
				b.winlostdate,
				b.APositiontaking,
				b.MPositiontaking,
				b.SPositiontaking,
				b.TPositiontaking,
				b.playerdiscount,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				b.matchid
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE 
				b.mrecommend = @CustId
				AND b.statusID IN (0, 1)
				AND b.transid > @MinTransId
		END
		ELSE IF @RoleId = 4		-- Super
		BEGIN
			INSERT INTO @MemBetTicket (
				TransId,
				RefNo,
				CustId,
				Username,
				DownlineCustId,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsType,
				Odds,
				Stake,
				Actual_Stake,
				Status,
				TransDate,
				WinLostDate,
				APositionTaking,
				MPositionTaking,
				SPositionTaking,
				TPositionTaking,
				PlayerDiscount,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				BetCheck,
				TransDesc,
				OddsSpread,
				ExtraInfo,
				MatchId)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.username,
				b.mrecommend AS DownlineCustId,
				b.bettype,
				ISNULL(b.betid, 0) AS BetId,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.status,
				b.transdate,
				b.winlostdate,
				b.APositiontaking,
				b.MPositiontaking,
				b.SPositiontaking,
				b.TPositiontaking,
				b.playerdiscount,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				b.matchid
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE b.srecommend = @CustId
				AND b.statusID IN (0, 1)
				AND b.transid > @MinTransId
		END

		SET @SubAccId = ISNULL(@SubAccId, 0)

		IF @SubAccId <> 0 AND @IsAllDownline = 0
		BEGIN
			DECLARE @DownlineList TABLE (CustId INT)

			INSERT INTO @DownlineList (CustId)
			SELECT DownlineId
			FROM dbo.CS_f_GetDownlineBySubAcc(@SubAccId)

			DELETE FROM @MemBetTicket
			WHERE DownlineCustId NOT IN (SELECT CustId FROM @DownlineList)
		END

		IF EXISTS (SELECT 1 FROM @MemBetTicket)
		BEGIN
			-- Check SP Version
			DECLARE @IsTest BIT = 0

			SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

			-- Get ticket info
			;WITH CTE_BetType AS (
				SELECT DISTINCT BetType, EventType
				FROM dbo.CS_SportBettypeMatrix WITH (NOLOCK)
				WHERE ProductID = 1
					AND (@SportTypeGroup = 0 OR SportTypeGroup = @SportTypeGroup)
					AND IsTest <= @IsTest
					AND (@BetTypeGroupList = ''
						OR ',' + @BetTypeGroupList + ',' LIKE '%,' + CONVERT(VARCHAR(5), BetTypeGroup) + ',%')
			)
			UPDATE b
			SET
				b.EventType = s.EventType,
				b.SportType = CASE
								WHEN s.EventType = 1 THEN m.sporttype
								WHEN s.EventType = 2 THEN l.sporttype
								ELSE 0
							END,
				b.LeagueId = CASE
								WHEN s.EventType = 1 THEN m.leagueid
								WHEN s.EventType = 2 THEN l.leagueid
								ELSE 0
							END,
				b.SportTypeGroup = CASE
										WHEN s.EventType = 0 THEN 9
										ELSE 0
									END,
				b.EventDate = CASE
								WHEN s.EventType = 1 THEN m.eventdate
								WHEN s.EventType = 2 THEN o.eventdate
								ELSE ''
							END,
				b.ShowTime = CASE
									WHEN s.EventType = 1 THEN m.GlobalShowTime
									ELSE ''
								END,
				b.EventStatus = CASE
									WHEN s.EventType = 1 THEN m.eventstatus
									ELSE ''
								END,
				b.Market = CASE
								WHEN s.EventType = 0 AND b.WinLostDate = CONVERT(DATE, CURRENT_TIMESTAMP) THEN 2					-- Today (Parlay)
								WHEN s.EventType = 0 AND b.WinLostDate > CONVERT(DATE, CURRENT_TIMESTAMP) THEN 3					-- Early (Parlay)
								WHEN s.EventType = 1 AND m.GlobalShowTime <= CURRENT_TIMESTAMP THEN 1								-- In-Play
								WHEN s.EventType = 1 AND CONVERT(DATE, m.GlobalShowTime) <= CONVERT(DATE, CURRENT_TIMESTAMP)
									AND m.GlobalShowTime > CURRENT_TIMESTAMP THEN 2													-- Today
								WHEN s.EventType = 1 AND CONVERT(DATE, m.GlobalShowTime) > CONVERT(DATE, CURRENT_TIMESTAMP) THEN 3	-- Early
								WHEN s.EventType = 2 AND o.eventdate = CONVERT(DATE, CURRENT_TIMESTAMP) THEN 2						-- Today (Outright)
								WHEN s.EventType = 2 AND o.eventdate > CONVERT(DATE, CURRENT_TIMESTAMP) THEN 3						-- Early (Outright)
								ELSE 0
							END
			FROM @MemBetTicket AS b
				INNER JOIN CTE_BetType AS s ON b.BetType = s.BetType
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId AND s.EventType = 1
				LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.matchid AND s.EventType = 2
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid AND s.EventType = 2

			DELETE FROM @MemBetTicket
			WHERE EventType IS NULL

			-- Get sporttype group
			;WITH CTE_SportType AS (
				SELECT DISTINCT SportType, BetType, SportTypeGroup
				FROM dbo.CS_SportBettypeMatrix WITH (NOLOCK)
				WHERE ProductID = 1
					AND (@SportTypeGroup = 0 OR SportTypeGroup = @SportTypeGroup)
					AND IsTest <= @IsTest
			)
			UPDATE b
			SET b.SportTypeGroup = s.SportTypeGroup
			FROM @MemBetTicket AS b
				INNER JOIN CTE_SportType AS s ON b.SportType = s.SportType AND b.BetType = s.BetType
			WHERE b.EventType <> 0

			-- Parse stake filter
			DECLARE @StakeFilter TABLE (SportTypeGroup TINYINT, Condition TINYINT, Stake MONEY)

			-- Get AgentList
			DECLARE @DocHandler INT

			BEGIN TRY
				EXEC sp_xml_preparedocument @DocHandler OUTPUT, @StakeList
		
				INSERT INTO @StakeFilter (SportTypeGroup, Condition, Stake)
				SELECT Id, Condition, Stake
				FROM OPENXML(@DocHandler, '/ROOT/SportTypeGroup', 1) WITH (Id TINYINT, Condition TINYINT, Stake MONEY) AS Data

				EXEC sp_xml_removedocument @DocHandler
			END TRY
			BEGIN CATCH
				SELECT ErrCode = 100,
					ErrMsg = N'Parameter invalid.'

				RETURN
			END CATCH

			-- Delete wrong tickets
			DELETE b
			FROM @MemBetTicket AS b
				LEFT JOIN @StakeFilter AS s ON b.SportTypeGroup = s.SportTypeGroup OR s.SportTypeGroup = 0
			WHERE b.SportTypeGroup = 0
				OR (s.Condition = 0 AND b.Stake <> s.Stake)
				OR (s.Condition = 1 AND b.Stake <= s.Stake)
				OR (s.Condition = 2 AND b.Stake >= s.Stake)
				OR (@Market <> ''
					AND ',' + @Market + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), b.Market) + ',%'
					AND b.EventType IN (1, 2))
				OR (@LeagueList <> ''
					AND b.EventType IN (1, 2)
					AND ',' + @LeagueList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(11), b.LeagueId) + ',%')
				OR (@MatchList <> '' AND b.EventType = 2)
				OR (@MatchList <> ''
					AND b.EventType = 1
					AND ',' + @MatchList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(11), b.MatchId) + ',%')

			-- Check for Parlay
			IF EXISTS (SELECT 1 FROM @MemBetTicket WHERE EventType = 0)
			BEGIN
				DECLARE @SubTicket TABLE (
					TransId		BIGINT,
					RefNo		BIGINT,
					BetType		SMALLINT,
					MatchId		INT,
					LeagueId	INT,
					EventStatus	NVARCHAR(50),
					ShowTime	DATETIME,
					Market		TINYINT )

				-- Get sub ticket info
				INSERT INTO @SubTicket
				SELECT
					bm.transid,
					bm.refno,
					bm.bettype,
					bm.matchid,
					m.leagueid,
					m.eventstatus,
					m.GlobalShowTime,
					CASE
						WHEN m.GlobalShowTime <= CURRENT_TIMESTAMP THEN 1																			-- In-Play
						WHEN CONVERT(DATE, m.GlobalShowTime) <= CONVERT(DATE, CURRENT_TIMESTAMP) AND m.GlobalShowTime > CURRENT_TIMESTAMP THEN 2	-- Today
						WHEN CONVERT(DATE, m.GlobalShowTime) > CONVERT(DATE, CURRENT_TIMESTAMP) THEN 3												-- Early
						ELSE 0
					END AS Market
				FROM @MemBetTicket AS b
					INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.RefNo = bm.refno
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
				WHERE b.EventType = 0

				-- Update Market = 1 (In-Play) for Parlay ticket which all sub tickets are In-Play)
				UPDATE b
				SET Market = 1
				FROM @MemBetTicket AS b
				WHERE EventType = 0
					AND NOT EXISTS (SELECT 1 FROM @SubTicket WHERE RefNo = b.RefNo AND Market <> 1)

				-- Delete wrong Parlay ticket
				DELETE b
				FROM @MemBetTicket AS b
				WHERE b.EventType = 0
					AND (NOT EXISTS (SELECT 1
									FROM @SubTicket AS bm
									WHERE bm.refno = b.RefNo
										AND (@LeagueList = '' OR ',' + @LeagueList + ',' LIKE '%,' + CONVERT(VARCHAR(11), bm.LeagueId) + ',%')
										AND (@MatchList = '' OR ',' + @MatchList + ',' LIKE '%,' + CONVERT(VARCHAR(11), bm.MatchId) + ',%'))
						OR (@Market <> ''
							AND ',' + @Market + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), b.Market) + ',%'))
			END
		END
	END

	-- Get max transid in bettrans
	SELECT @MinTransId = MAX(transid)
	FROM dbo.bettrans WITH (NOLOCK)

	-- Return data
	SELECT TOP(@PageSize)
		b.TransId,
		b.RefNo,
		b.CustId,
		b.Username,
		b.BetType,
		b.BetId,
		b.BetTeam,
		b.Hdp1,
		b.Hdp2,
		b.OddsType,
		b.Odds,
		b.Stake,
		b.Actual_Stake,
		b.Status,
		b.TransDate,
		b.APositionTaking,
		b.MPositionTaking,
		b.SPositionTaking,
		b.TPositionTaking,
		b.PlayerDiscount,
		b.LiveIndicator,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.Ip,
		b.BetCheck,
		b.TransDesc,
		b.OddsSpread,
		b.ExtraInfo,
		b.MatchId,
		b.SportType,
		b.LeagueId,
		c.ugroup
	FROM @MemBetTicket AS b
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid
	ORDER BY b.TransId DESC
END
GO




GRANT EXECUTE ON [dbo].[CS_Monitor_BetList] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[CS_Monitor_BetList] TO [bodbDownlineNetView] AS [dbo]
GO
