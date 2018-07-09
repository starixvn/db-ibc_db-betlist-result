/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetListbyIP_Username]
	@FromDate		DATETIME,
	@Ip				VARCHAR(15),
	@UserId			INT			= NULL,
	@MoveBetsDay	SMALLDATETIME,
	@SiteType		TINYINT		= 0
AS

/*
	Created by: Jamie@20090318
	Task: Total bet by IP and Username 
	DB: DBACC.bodb02
	
	Parameter Explanantion
		- @SiteType:
			- 0 : Get all
			- 1 : Exclude deposit sites
			- 2 : Exclude credit sites

	Revisions:
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20110516@Lukas: Rearrange bettype
		- 20110802@Johnson: Add new bettype combination mix parlay
		- 20120626@Lukas: Check case of matchid = orid
		- 20130904@Daniel: Remove condition bettype < 19001 when querying bettrans14 since it's useless => optimize performance
		- 20140303@Elodie: Add Keno product [Redmine:#12756]
		- 20150506@Tom: Support Gold Deluxe Product [#34847]
		- 20150615@Edward: Support for BetTrade
		- 20150707@Bobby: Add metric gaming bettypes (801-899)
		- 20150715@Edward: Support for Micro Gaming
		- 20150831@Kos: Support for Colossus Bet
		- 20151216@Kos: Support for Cockfighting
		- 20160621@Kos: Hide special sites from unauthorized users [#Redmine: 48948]
		- 20160711@Kos: Change to use inline function for SportBettypeMatrix
		- 20160804@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20170315@Kos: Exclude bet type 913, 914 [#Redmine: 71963]
		- 20170629@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20171025@Kos: Support Bullfighting [#Redmine: 84961]
					- Don't support Live Casino anymore
		- 20180130@Kos: Don't support Racing, Cockfighting, RNG Casino (bettype 71, 72) anymore [#Redmine: 86086]
		- 20180808@Helen: DB05.DBPOLICY migration - [Redmine:99462]
		- 20180727@Kos: Add new permission to view Licensee account [#Redmine: 96118]
*/

 BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID NOT IN (2, 4, 7, 9, 19)
		AND (ProductID <> 6 OR SubProduct <> '')
	
	DECLARE @UserTicketTmp TABLE (
		CustId		INT,
		TotalBet	INT,
		Type		TINYINT) --Type: 1: Ticket in bettrans, 2: Ticket in translog

	INSERT INTO @UserTicketTmp
	SELECT custid,
		COUNT(custid),
		1
	FROM dbo.bettrans WITH (NOLOCK)
	WHERE winlostdate = @FromDate
		AND bettype < 19001
		AND bettype NOT IN (903, 904, 913, 914)
		AND ip = @Ip
		--exclude metric gaming running ticket
		AND (bettype NOT BETWEEN 801 AND 806
			OR (bettype BETWEEN 801 AND 806 AND statusID NOT IN (0, 1)))
	GROUP BY custid

	UNION ALL

	SELECT
		tl.custid,
		COUNT(tl.custid),
		2
	FROM dbo.translog AS tl WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON tl.gameid = sp.BetType
	WHERE tl.winlostdate = @FromDate
		AND tl.ip = @Ip
		AND tl.statusID IN (0, 1)
		AND (sp.ProductID IN (8, 12, 13, 15, 28, 30)
			OR tl.gameid BETWEEN 801 AND 899)
	GROUP BY tl.custid

	CREATE TABLE #tmpUserBet (
		CustId		INT,
		SoccerBet	INT DEFAULT 0,
		TotalBet	INT DEFAULT 0,
		Is14		BIT DEFAULT 0,
		PRIMARY KEY(CustId, Is14) )

	IF @FromDate > @MoveBetsDay
	BEGIN
		INSERT #tmpUserBet (CustId, TotalBet)
		SELECT CustId,
			SUM(TotalBet)
		FROM @UserTicketTmp
		GROUP BY CustId

		UPDATE #tmpUserBet
		SET soccerBet = tmpSoccerBet.totalSoccer
		FROM #tmpUserBet AS u
			INNER JOIN
			(
				SELECT custid,
					COUNT(custid) AS totalSoccer
				FROM (
						SELECT b.custid
						FROM dbo.bettrans AS b WITH (NOLOCK)
							INNER JOIN (
									SELECT
										matchid,
										leagueid,
										'match' AS type
									FROM dbo.match WITH (NOLOCK)
									UNION ALL
									SELECT
										orid,
										leagueid,
										'outright' AS type
									FROM dbo.outright WITH (NOLOCK)
								) m ON b.matchid = m.matchid
							INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
							INNER JOIN dbo.sports AS s WITH (NOLOCK) ON l.sporttype = s.sporttype
						WHERE
							b.winlostdate = @FromDate
							AND s.SportType = 1
							AND b.bettype NOT IN (903, 904, 913, 914)
							AND b.ip = @Ip
							AND m.type = CASE WHEN b.bettype = 10 THEN 'outright' ELSE 'match' END
							--exclude metric gaming running ticket
							AND (b.bettype NOT BETWEEN 801 AND 806
								OR (b.bettype BETWEEN 801 AND 806 AND b.statusID NOT IN (0, 1)))
						UNION ALL
						SELECT b.custid
						FROM dbo.bettrans AS b WITH (NOLOCK) 
						WHERE 1 = CASE
									WHEN b.bettype = 9 AND b.matchid = 9 THEN 1
									WHEN b.bettype = 29 AND b.matchid = 29 THEN 1
									ELSE 0
								END
							AND b.winlostdate = @FromDate
							AND b.ip = @Ip
							AND b.refno IN (SELECT bm.refno
											FROM dbo.bettransm AS bm WITH (NOLOCK) 
												INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
											WHERE m.sporttype = 1)
						--COUNT MG ticket as soccer
						UNION ALL
						SELECT custid
						FROM dbo.translog WITH (NOLOCK)
						WHERE winlostdate = @FromDate
							AND gameid BETWEEN 801 AND 899
							AND ip = @Ip
							AND statusID IN (0, 1)
					) Bet
				GROUP BY custid
			) tmpSoccerBet ON tmpSoccerBet.custid = u.custid
	END
	ELSE
	BEGIN
		INSERT #tmpUserBet (CustId, TotalBet, Is14)
		SELECT custid,
			COUNT(custid),
			1
		FROM dbo.bettrans14 WITH (NOLOCK)
		WHERE winlostdate = @FromDate AND ip = @Ip
		GROUP BY custid

		UPDATE #tmpUserBet
		SET soccerBet = tmpSoccerBet.totalSoccer
		FROM #tmpUserBet AS u
			INNER JOIN
			(
				SELECT custid,
					COUNT(custid) AS totalSoccer
				FROM (
						SELECT b.custid
						FROM dbo.bettrans14 AS b WITH (NOLOCK)
							INNER JOIN (
									SELECT
										matchid,
										leagueid,
										'match' AS type
									FROM dbo.match14 WITH (NOLOCK)
									UNION ALL
									SELECT
										orid,
										leagueid,
										'outright' AS type
									FROM dbo.outright14 WITH (NOLOCK)
								) m ON b.matchid = m.matchid
							INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
							INNER JOIN dbo.sports AS s WITH (NOLOCK) ON l.sporttype = s.sporttype
						WHERE b.winlostdate = @FromDate
							AND s.SportType = 1
							AND b.bettype NOT IN (903, 904, 913, 914)
							AND b.ip = @Ip
							AND m.type = CASE WHEN b.bettype = 10 THEN 'outright' ELSE 'match' END
						UNION ALL
						SELECT b.custid
						FROM dbo.bettrans14 AS b WITH (NOLOCK)
						WHERE 1 = CASE
										WHEN b.bettype = 9 AND b.matchid = 9 THEN 1
										WHEN b.bettype = 29 AND b.matchid = 29 THEN 1
										ELSE 0
									END
							AND b.winlostdate = @FromDate
							AND b.ip = @Ip
							AND b.refno IN (SELECT bm.refno
											FROM dbo.bettransm14 AS bm WITH (NOLOCK)
												INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
											WHERE m.sporttype = 1)
						) Bet
				GROUP BY custid
			) tmpSoccerBet ON tmpSoccerBet.custid = u.custid AND u.is14 = 1
	END

	DECLARE @DeniedSite TABLE (
		SiteId			INT,
		Site			NVARCHAR(50),
		SpecialGroup	TINYINT)

	DECLARE @tmpUserid VARCHAR(50),
		@SearchQuery VARCHAR(1024)

	SELECT @tmpUserid = CAST(@UserId AS VARCHAR(50))

	SELECT @SearchQuery = 'SELECT * 
		FROM OPENQUERY(DBPOL, 
		''SELECT siteid, site, SpecialGroup FROM NAP_UserControl.dbo.f_GetDeniedSiteByUser( ''''' + @tmpUserid + ''''')'')'

	INSERT INTO @DeniedSite (siteid, site, SpecialGroup)
	EXECUTE(@SearchQuery)

	IF @SiteType <> 0
	BEGIN
		INSERT INTO  @DeniedSite (SiteId, Site, SpecialGroup)
		SELECT
			s.siteid,
			s.site,
			s.SpecialGroup
		FROM dbo.Site AS s WITH (NOLOCK)
		WHERE NOT EXISTS (SELECT 1 FROM @DeniedSite WHERE SiteId = s.siteid)
			AND s.isLicensee = CASE
								WHEN @SiteType = 1 THEN 1
								WHEN @SiteType = 2 THEN 0
							END
	END

	SELECT c.custid,
		c.username,
		SUM(u.SoccerBet) AS soccerBet,
		SUM(u.TotalBet)- SUM(u.SoccerBet) AS otherBet,
		SUM(u.TotalBet) AS totalBet
	FROM #tmpUserBet AS u
		INNER JOIN dbo.customer AS c WITH (NOLOCK) ON u.custid = c.custid
		INNER JOIN dbo.customer AS a WITH (NOLOCK) ON c.recommend = a.custid
	WHERE a.site NOT IN (SELECT Site FROM @DeniedSite)
	GROUP BY c.custid,
		c.username
	ORDER BY c.username

	DROP TABLE #tmpUserBet
END



GO
GRANT EXECUTE ON [dbo].[Acc_BetListbyIP_Username] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetListbyIP_Username] TO [vnteam] AS [dbo]
GO
