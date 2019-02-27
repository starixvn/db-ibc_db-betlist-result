/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_BetList_TotalBets_Match]
	@CustId			INT,
	@RoleId			TINYINT,
	@MatchId		INT				= 0,
	@BetTypeGroup	SMALLINT		= 0,
	@LiveIndicator	TINYINT			= 2,
	@BetTeam		NVARCHAR(10)	= '',
	@StakeCondition TINYINT			= 1,
	@Stake			MONEY			= 0
AS

/*
	Created: Kos@20190314
	Task: Bet List of CN88 Total Bets Match
	DB: DB042.bodb02

	Param's Explanation:
		- @RoleId: role ID
			- 1: Member
			- 2: Agent
			- 3: Master
			- 4: Super
		- @LiveIndicator:
			- 0: Non-Live
			- 1: Live
			- 2: All (Non-Live & Live)
		- @StakeCondition:
			- 0: =
			- 1: >
			- 2: <

	Revisions:
		- 20190314@Kos: Create new [Redmine: 109230]
		
*/

BEGIN
	SET NOCOUNT ON;

	-- Check SP Version
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @BetTypeList TABLE (BetType SMALLINT)

	INSERT INTO @BetTypeList
	SELECT DISTINCT BetType
	FROM dbo.CS_SportBettypeMatrix WITH (NOLOCK)
	WHERE BetTypeGroup = @BetTypeGroup AND IsTest <= @IsTest

	-- Member
	IF @RoleId = 1
	BEGIN
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.username,
			m.sporttype,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'Waiting'
				ELSE b.status
			END AS Status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			b.APositiontaking,
			b.MPositiontaking,
			b.SPositiontaking,
			b.TPositiontaking,
			b.playerdiscount,
			b.discount AS ADiscount,
			b.adiscount AS MDiscount,
			b.sdiscount AS SDiscount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			m.leagueid,
			m.matchid,
			m.matchcode,
			m.eventdate,
			m.homeid,
			m.awayid,
			m.betstatus,
			ISNULL(m.IsNeutral, 0) AS IsNeutral,
			CASE
				WHEN b.bettype IN (216, 217) THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			b.currencyname AS Currency,
			c.ugroup
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
		WHERE b.custid = @CustId
			AND b.statusID IN (0, 1)
			AND b.matchid = @MatchId
			AND b.bettype IN (SELECT BetType FROM @BetTypeList)
			AND (@LiveIndicator = 2 OR b.liveindicator = @LiveIndicator)
			AND (@BetTeam = '' OR b.betteam = @BetTeam)
			AND ((@StakeCondition = 0 AND b.Stake = @Stake)
				OR (@StakeCondition = 1 AND b.Stake > @Stake)
				OR (@StakeCondition = 2 AND b.Stake < @Stake))
		ORDER BY b.transid DESC
	END
	ELSE IF @RoleId = 2		-- Agent
	BEGIN
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.username,
			m.sporttype,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'Waiting'
				ELSE b.status
			END AS Status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			b.APositiontaking,
			b.MPositiontaking,
			b.SPositiontaking,
			b.TPositiontaking,
			b.playerdiscount,
			b.discount AS ADiscount,
			b.adiscount AS MDiscount,
			b.sdiscount AS SDiscount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			m.leagueid,
			m.matchid,
			m.matchcode,
			m.eventdate,
			m.homeid,
			m.awayid,
			m.betstatus,
			ISNULL(m.IsNeutral, 0) AS IsNeutral,
			CASE
				WHEN b.bettype IN (216, 217) THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			b.currencyname AS Currency,
			c.ugroup
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
		WHERE b.recommend = @CustId
			AND b.statusID IN (0, 1)
			AND b.matchid = @MatchId
			AND b.bettype IN (SELECT BetType FROM @BetTypeList)
			AND (@LiveIndicator = 2 OR b.liveindicator = @LiveIndicator)
			AND (@BetTeam = '' OR b.betteam = @BetTeam)
			AND ((@StakeCondition = 0 AND b.Stake = @Stake)
				OR (@StakeCondition = 1 AND b.Stake > @Stake)
				OR (@StakeCondition = 2 AND b.Stake < @Stake))
		ORDER BY b.transid DESC
	END
	ELSE IF @RoleId = 3		-- Master
	BEGIN
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.username,
			m.sporttype,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'Waiting'
				ELSE b.status
			END AS Status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			b.APositiontaking,
			b.MPositiontaking,
			b.SPositiontaking,
			b.TPositiontaking,
			b.playerdiscount,
			b.discount AS ADiscount,
			b.adiscount AS MDiscount,
			b.sdiscount AS SDiscount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			m.leagueid,
			m.matchid,
			m.matchcode,
			m.eventdate,
			m.homeid,
			m.awayid,
			m.betstatus,
			ISNULL(m.IsNeutral, 0) AS IsNeutral,
			CASE
				WHEN b.bettype IN (216, 217) THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			b.currencyname AS Currency,
			c.ugroup
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
		WHERE b.mrecommend = @CustId
			AND b.statusID IN (0, 1)
			AND b.matchid = @MatchId
			AND b.bettype IN (SELECT BetType FROM @BetTypeList)
			AND (@LiveIndicator = 2 OR b.liveindicator = @LiveIndicator)
			AND (@BetTeam = '' OR b.betteam = @BetTeam)
			AND ((@StakeCondition = 0 AND b.Stake = @Stake)
				OR (@StakeCondition = 1 AND b.Stake > @Stake)
				OR (@StakeCondition = 2 AND b.Stake < @Stake))
		ORDER BY b.transid DESC
	END
	ELSE IF @RoleId = 4		-- Super
	BEGIN
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.username,
			m.sporttype,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'Waiting'
				ELSE b.status
			END AS Status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			b.APositiontaking,
			b.MPositiontaking,
			b.SPositiontaking,
			b.TPositiontaking,
			b.playerdiscount,
			b.discount AS ADiscount,
			b.adiscount AS MDiscount,
			b.sdiscount AS SDiscount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			m.leagueid,
			m.matchid,
			m.matchcode,
			m.eventdate,
			m.homeid,
			m.awayid,
			m.betstatus,
			ISNULL(m.IsNeutral, 0) AS IsNeutral,
			CASE
				WHEN b.bettype IN (216, 217) THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			b.currencyname AS Currency,
			c.ugroup
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
		WHERE b.srecommend = @CustId
			AND b.statusID IN (0, 1)
			AND b.matchid = @MatchId
			AND b.bettype IN (SELECT BetType FROM @BetTypeList)
			AND (@LiveIndicator = 2 OR b.liveindicator = @LiveIndicator)
			AND (@BetTeam = '' OR b.betteam = @BetTeam)
			AND ((@StakeCondition = 0 AND b.Stake = @Stake)
				OR (@StakeCondition = 1 AND b.Stake > @Stake)
				OR (@StakeCondition = 2 AND b.Stake < @Stake))
		ORDER BY b.transid DESC
	END
END
GO




GRANT EXECUTE ON [dbo].[CS_BetList_TotalBets_Match] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[CS_BetList_TotalBets_Match] TO [bodbDownlineNetView] AS [dbo]
GO
