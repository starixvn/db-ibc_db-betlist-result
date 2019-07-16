/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_BetList_TotalBets_Outright]
	@CustId			INT,
	@RoleId			TINYINT,
	@SubAccId		INT			= 0,
	@IsAllDownline	BIT			= 0,
	@OrId			INT,
	@StakeCondition TINYINT		= 1,
	@Stake			MONEY		= 0
AS

/*
	Created: Kos@20190314
	Task: Bet List of CN88 Total Bets Outright
	DB: DB042.bodb02

	Param's Explanation:
		- @RoleId: role ID
			- 1: Member
			- 2: Agent
			- 3: Master
			- 4: Super
		- @SubAccId: Sub Account ID
		- @IsAllDownline:
			- 0: Not view all downline of CustId
			- 1: View all downline of CustId
		- @OrId: Outright ID
		- @StakeCondition:
			- 0: =
			- 1: >
			- 2: <

	Revisions:
		- 20190314@Kos: Create new [Redmine: 109230]
		- 20190716@Kos: Support subaccount permission [Redmine: #116825]
					- Add new params @SubAccId, @IsAllDownline
*/

BEGIN
	SET NOCOUNT ON;

	-- Member
	IF @RoleId = 1
	BEGIN
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.username,
			l.sporttype,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.odds,
			b.modds,
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
			b.discount AS ADiscount,
			b.adiscount AS MDiscount,
			b.sdiscount AS SDiscount,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			o.leagueid,
			0 AS MatchId,
			o.matchcode AS MatchCode,
			o.groupmatch AS Race,
			o.eventdate AS EventDate,
			o.teamid AS HomeId,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
			b.currencyname AS Currency,
			c.ugroup
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueID = l.leagueid
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
		WHERE b.custid = @CustId
			AND b.statusID IN (0, 1)
			AND b.bettype = 10
			AND b.matchid = @OrId
			AND ((@StakeCondition = 0 AND b.Stake = @Stake)
				OR (@StakeCondition = 1 AND b.Stake > @Stake)
				OR (@StakeCondition = 2 AND b.Stake < @Stake))
		ORDER BY b.transid DESC
	END
	ELSE
	BEGIN
		SET @SubAccId = ISNULL(@SubAccId, 0)

		IF @SubAccId = 0 OR @IsAllDownline = 1
		BEGIN
			IF @RoleId = 2		-- Agent
			BEGIN
				SELECT
					b.transid,
					b.refno,
					b.custid,
					b.username,
					l.sporttype,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
					b.odds,
					b.modds,
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
					b.discount AS ADiscount,
					b.adiscount AS MDiscount,
					b.sdiscount AS SDiscount,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					o.leagueid,
					0 AS MatchId,
					o.matchcode AS MatchCode,
					o.groupmatch AS Race,
					o.eventdate AS EventDate,
					o.teamid AS HomeId,
					CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
					b.currencyname AS Currency,
					c.ugroup
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueID = l.leagueid
					INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
				WHERE b.recommend = @CustId
					AND b.statusID IN (0, 1)
					AND b.bettype = 10
					AND b.matchid = @OrId
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
					l.sporttype,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
					b.odds,
					b.modds,
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
					b.discount AS ADiscount,
					b.adiscount AS MDiscount,
					b.sdiscount AS SDiscount,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					o.leagueid,
					0 AS MatchId,
					o.matchcode AS MatchCode,
					o.groupmatch AS Race,
					o.eventdate AS EventDate,
					o.teamid AS HomeId,
					CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
					b.currencyname AS Currency,
					c.ugroup
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueID = l.leagueid
					INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
				WHERE b.mrecommend = @CustId
					AND b.statusID IN (0, 1)
					AND b.bettype = 10
					AND b.matchid = @OrId
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
					l.sporttype,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
					b.odds,
					b.modds,
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
					b.discount AS ADiscount,
					b.adiscount AS MDiscount,
					b.sdiscount AS SDiscount,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					o.leagueid,
					0 AS MatchId,
					o.matchcode AS MatchCode,
					o.groupmatch AS Race,
					o.eventdate AS EventDate,
					o.teamid AS HomeId,
					CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
					b.currencyname AS Currency,
					c.ugroup
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueID = l.leagueid
					INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
				WHERE b.srecommend = @CustId
					AND b.statusID IN (0, 1)
					AND b.bettype = 10
					AND b.matchid = @OrId
					AND ((@StakeCondition = 0 AND b.Stake = @Stake)
						OR (@StakeCondition = 1 AND b.Stake > @Stake)
						OR (@StakeCondition = 2 AND b.Stake < @Stake))
				ORDER BY b.transid DESC
			END
		END
		ELSE
		BEGIN
			DECLARE @DownlineList TABLE (CustId INT)

			INSERT INTO @DownlineList (CustId)
			SELECT DownlineId
			FROM dbo.CS_f_GetDownlineBySubAcc(@SubAccId)

			IF @RoleId = 2		-- Agent
			BEGIN
				SELECT
					b.transid,
					b.refno,
					b.custid,
					b.username,
					l.sporttype,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
					b.odds,
					b.modds,
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
					b.discount AS ADiscount,
					b.adiscount AS MDiscount,
					b.sdiscount AS SDiscount,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					o.leagueid,
					0 AS MatchId,
					o.matchcode AS MatchCode,
					o.groupmatch AS Race,
					o.eventdate AS EventDate,
					o.teamid AS HomeId,
					CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
					b.currencyname AS Currency,
					c.ugroup
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueID = l.leagueid
					INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
				WHERE b.recommend = @CustId
					AND b.custid IN (SELECT CustId FROM @DownlineList)
					AND b.statusID IN (0, 1)
					AND b.bettype = 10
					AND b.matchid = @OrId
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
					l.sporttype,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
					b.odds,
					b.modds,
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
					b.discount AS ADiscount,
					b.adiscount AS MDiscount,
					b.sdiscount AS SDiscount,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					o.leagueid,
					0 AS MatchId,
					o.matchcode AS MatchCode,
					o.groupmatch AS Race,
					o.eventdate AS EventDate,
					o.teamid AS HomeId,
					CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
					b.currencyname AS Currency,
					c.ugroup
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueID = l.leagueid
					INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
				WHERE b.mrecommend = @CustId
					AND b.recommend IN (SELECT CustId FROM @DownlineList)
					AND b.statusID IN (0, 1)
					AND b.bettype = 10
					AND b.matchid = @OrId
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
					l.sporttype,
					b.bettype,
					ISNULL(b.betid, 0) AS BetId,
					b.odds,
					b.modds,
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
					b.discount AS ADiscount,
					b.adiscount AS MDiscount,
					b.sdiscount AS SDiscount,
					b.livehomescore,
					b.liveawayscore,
					b.ip,
					o.leagueid,
					0 AS MatchId,
					o.matchcode AS MatchCode,
					o.groupmatch AS Race,
					o.eventdate AS EventDate,
					o.teamid AS HomeId,
					CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
					b.currencyname AS Currency,
					c.ugroup
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueID = l.leagueid
					INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.custid = c.custid
				WHERE b.srecommend = @CustId
					AND b.mrecommend IN (SELECT CustId FROM @DownlineList)
					AND b.statusID IN (0, 1)
					AND b.bettype = 10
					AND b.matchid = @OrId
					AND ((@StakeCondition = 0 AND b.Stake = @Stake)
						OR (@StakeCondition = 1 AND b.Stake > @Stake)
						OR (@StakeCondition = 2 AND b.Stake < @Stake))
				ORDER BY b.transid DESC
			END
		END
	END
END
GO




GRANT EXECUTE ON [dbo].[CS_BetList_TotalBets_Outright] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[CS_BetList_TotalBets_Outright] TO [bodbDownlineNetView] AS [dbo]
GO
