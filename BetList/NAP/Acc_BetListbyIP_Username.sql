ALTER PROCEDURE [dbo].[Acc_BetListbyIP_Username]
	@FromDate	DATETIME,
	@Ip			VARCHAR(15),
	@UserId		INT			= NULL
AS

/*
	Created by: Phuong Dao
	Date: 2009-03-18
	Task: Total bet by IP and Username 
	DB: DBACC/bodb02

	Revisions:
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20110516@Lukas: re-arrange bettype
		- 20110802@Johnson: Add new bettype combination mix parlay
		- 20120626@Lukas: check case of matchid = orid
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
*/

 BEGIN
	SET NOCOUNT ON

	----Get Sport Bettype Matrix------
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM bodb02.dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)

	DECLARE @min_date	SMALLDATETIME,
			@max_date	SMALLDATETIME,
			@min_date14	SMALLDATETIME,
			@max_date14	SMALLDATETIME
	
	SELECT @min_date = MIN(winlostdate),
		@max_date = MAX(winlostdate)
	FROM dbo.bettrans WITH (NOLOCK)
	WHERE bettype < 19001

	SELECT @min_date14 = MIN(winlostdate),
		@max_date14 = MAX(winlostdate)
	FROM dbo.bettrans14 WITH (NOLOCK)
	
	DECLARE @UserTicketTmp TABLE (
		custid		INT,
		totalBet	INT,
		Type		TINYINT) --Type: 1: Ticket in bettrans, 2: Ticket in translog (for Keno)

	INSERT INTO @UserTicketTmp (custid, totalBet, Type)
	SELECT b.custid,
		COUNT(b.custid),
		1
	FROM dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.winlostdate = @FromDate
		AND b.bettype < 19001
		AND b.bettype NOT IN (903, 904)
		AND b.ip = @Ip
		--exclude metric gaming running ticket
		AND (b.bettype NOT BETWEEN 801 AND 806
			OR (b.bettype BETWEEN 801 AND 806 AND b.statusID NOT IN (0, 1)))
	GROUP BY custid

	UNION ALL

	SELECT
		tl.custid,
		COUNT(tl.custid),
		2
	FROM dbo.translog AS tl WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp
			ON tl.gameid = sp.BetType
				AND (sp.ProductID IN (8, 12, 13, 15, 19) OR tl.gameid BETWEEN 801 AND 899)
	WHERE tl.winlostdate = @FromDate
		--AND gameid between 1501 and 1599
		AND tl.ip = @Ip 
		AND tl.statusID = 0
	GROUP BY tl.custid

	CREATE TABLE #tmpUserBet (
		custid		INT,
		soccerBet	INT DEFAULT 0,
		totalBet	INT DEFAULT 0,
		is14		BIT DEFAULT 0,
		PRIMARY KEY(CustID,is14) )

	IF @FromDate >= @min_date AND @FromDate <= @max_date
	BEGIN
		INSERT #tmpUserBet (custid, totalBet)
		SELECT custid,
			SUM(totalBet)
		FROM @UserTicketTmp
		GROUP BY custid

		UPDATE #tmpUserBet
		SET soccerBet = tmpSoccerBet.totalSoccer
		FROM #tmpUserBet u
			INNER JOIN
			(
				SELECT custid,
					COUNT(custid) AS totalSoccer
				FROM (
						SELECT b.custid
						FROM dbo.bettrans AS b WITH (NOLOCK)
							INNER JOIN (
									SELECT matchid, leagueid, 'match' AS type
									FROM dbo.match WITH (NOLOCK)
									UNION ALL
									SELECT orid, leagueid, 'outright' AS type
									FROM dbo.outright WITH (NOLOCK)
								) m ON b.matchid = m.matchid
							INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
							INNER JOIN dbo.sports AS s WITH (NOLOCK) ON l.sporttype = s.sporttype
						WHERE
							b.winlostdate = @FromDate
							AND s.SportType = 1 
							AND b.bettype NOT IN (903, 904)
							AND b.ip = @ip
							AND m.type = CASE WHEN b.bettype = 10 THEN 'outright' ELSE 'match' END
							--exclude metric gaming running ticket
							AND (b.bettype NOT BETWEEN 801 AND 806
								OR (b.bettype BETWEEN 801 AND 806 AND b.statusID NOT IN (0, 1)))
						UNION ALL
						SELECT b.custid
						FROM dbo.bettrans b WITH (NOLOCK) 
						WHERE 1 = CASE WHEN b.bettype = 9 AND b.matchid = 9 THEN 1
										WHEN b.bettype = 29 AND b.matchid = 29 THEN 1
										ELSE 0 END
							AND b.winlostdate = @FromDate
							AND b.ip = @Ip
							AND b.refno IN (SELECT refno
											FROM dbo.bettransm AS bm WITH (NOLOCK) 
												INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
											WHERE 	m.sporttype = 1)
						--COUNT MG ticket as soccer
						UNION ALL 
						SELECT tl.custid
						FROM dbo.translog AS tl WITH (NOLOCK)
						WHERE winlostdate = @fromdate 
							AND tl.gameid BETWEEN 801 AND 899
							AND ip = @ip
							AND statusid = 0
					) Bet
				GROUP BY custid
			) tmpSoccerBet ON tmpSoccerBet.custid = u.custid
	END

	IF @FromDate >= @min_date14 AND @FromDate <= @max_date14
	BEGIN
		INSERT #tmpUserBet (custid, totalBet, is14)
		SELECT custid,
			COUNT(custid),
			1
		FROM dbo.bettrans14 WITH (NOLOCK)
		WHERE winlostdate = @fromdate AND ip = @ip
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
									SELECT matchid, leagueid, 'match' AS type
									FROM dbo.match14 WITH (NOLOCK)
									UNION ALL
									SELECT orid, leagueid, 'outright' AS type
									FROM dbo.outright14 WITH (NOLOCK)
								) m ON b.matchid = m.matchid
							INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
							INNER JOIN dbo.sports AS s WITH (NOLOCK) ON l.sporttype = s.sporttype
						WHERE b.winlostdate = @FromDate
							AND s.SportType = 1
							AND b.bettype NOT IN (903, 904)
							AND b.ip = @Ip
							AND m.type = CASE WHEN b.bettype = 10 THEN 'outright' ELSE 'match' END
						UNION ALL
						SELECT b.custid
						FROM dbo.bettrans14 AS b WITH (NOLOCK)
						WHERE 1 = CASE WHEN b.bettype = 9 AND b.matchid = 9 THEN 1
										WHEN b.bettype = 29 AND b.matchid = 29 THEN 1
										ELSE 0 END
							AND b.winlostdate = @FromDate
							AND b.ip = @Ip
							AND b.refno IN (SELECT refno
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

	DECLARE @Sql VARCHAR(500)

	SET @Sql = 'SELECT * 
				FROM OPENQUERY(DBPOLICY,
					''SELECT siteid, site, SpecialGroup
					FROM bodb02.dbo.f_GetDeniedSiteByUser( ''''' + CAST(@Userid AS VARCHAR(50)) + ''''')'')'

	INSERT INTO @DeniedSite
	EXEC (@Sql)

	SELECT c.custid,
		c.username,
		SUM(soccerBet) AS soccerBet,
		SUM(totalBet)- SUM(soccerBet) AS otherBet,
		SUM(totalBet) AS totalBet
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