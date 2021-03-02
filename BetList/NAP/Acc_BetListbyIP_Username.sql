/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetListbyIP_Username]
	@FromDate		SMALLDATETIME,
	@Ip				VARCHAR(15),
	@UserId			INT			= NULL,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@Permission		VARCHAR(20)		= '1,2,3'
AS

/*
	Created by: Jamie@20090318
	Task: Total bet by IP and Username 
	DB: DBACC.bodb02
	
	Parameter Explanantion
		- @Permission
			- 1: Credit sites
			- 2: Deposit sites
			- 3: CN88

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
		- 20190531@Kos: Add new input param @Permission VARCHAR(20) [#Redmine: 114125]
					- Remove param @SiteType
		- 20190823@Kos: Support bk range [#Redmine: 119018]
		- 20191218@Kos: Support Virtual Games [Redmine: #124759]
		- 20200323@Kos: Support Indo 4D [Redmine: #130857]
		- 20200402@Kos: Support Table Games [Redmine: #129433]
		- 20201028@Kos: Change data type of @FromDate [Redmine: #144388]
		- 20201126@Kos: Support Leap Gaming Virtual Sports 3 [Redmine: #131371]
		- 20201224@Razor: Support Happy 5 Linked Games [Redmine: #146540]
		- 20210301@Razor: Support Sports Lottery [Redmine: #147368]
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
	WHERE ProductID NOT IN (2, 4, 7, 9, 13, 17, 19, 26, 30, 31, 33)
		AND (ProductID <> 6 OR SubProduct <> '')

	DECLARE @UserTicket TABLE (
		CustId		INT,
		BetType		SMALLINT,
		MatchId		INT,
		RefNo		BIGINT,
		SoccerBet	INT,
		TotalBet	INT)

	IF @FromDate > @MoveBetsDay		-- bettrans range
	BEGIN
		-- bettrans
		INSERT INTO @UserTicket
		SELECT
			custid,
			bettype,
			matchid,
			CASE
				WHEN bettype = 29 THEN refno
				ELSE 0
			END,
			0 AS SoccerBet,
			COUNT(1) AS TotalBet
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE winlostdate = @FromDate
			AND ip = @Ip
			AND bettype < 19001
			AND bettype NOT IN (903, 904, 913, 914)
			AND (bettype NOT BETWEEN 801 AND 806
				OR statusID NOT IN (0, 1))
		GROUP BY
			custid,
			bettype,
			matchid,
			CASE
				WHEN bettype = 29 THEN refno
				ELSE 0
			END

		-- normal Soccer ticket
		UPDATE b
		SET b.SoccerBet = b.TotalBet
		FROM @UserTicket AS b
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.MatchId = m.matchid
		WHERE m.sporttype = 1 AND b.BetType <> 10

		-- outright Soccer ticket
		UPDATE b
		SET b.SoccerBet = b.TotalBet
		FROM @UserTicket AS b
			INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.MatchId
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
		WHERE l.sporttype = 1 AND b.BetType = 10

		-- parlay Soccer ticket
		UPDATE b
		SET b.SoccerBet = b.TotalBet
		FROM @UserTicket AS b
		WHERE b.BetType = 29
			AND EXISTS (SELECT 1
						FROM dbo.bettransm AS bm WITH (NOLOCK)
							INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
						WHERE m.sporttype = 1 AND bm.refno = b.RefNo)

		-- translog
		INSERT INTO @UserTicket
		SELECT
			custid,
			0,
			0,
			0,
			SUM(CASE WHEN gameID BETWEEN 801 AND 899 THEN 1 ELSE 0 END) AS SoccerBet,
			COUNT(1) AS TotalBet
		FROM dbo.translog AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON b.gameID = s.Bettype
		WHERE b.winlostdate = @FromDate
			AND b.ip = @Ip
			AND b.statusID IN (0, 1)
			AND (s.productID IN (8, 12, 15, 28, 38, 40, 43, 49, 63)
				OR b.gameID BETWEEN 801 AND 899
				OR (s.productID = 3 AND s.EventType = 0))
		GROUP BY b.custid
	END
	ELSE IF @FromDate BETWEEN @BalanceUpDay AND @MoveBetsDay
	BEGIN
		INSERT INTO @UserTicket
		SELECT
			custid,
			bettype,
			matchid,
			CASE
				WHEN bettype = 29 THEN refno
				ELSE 0
			END,
			0 AS SoccerBet,
			COUNT(1) AS TotalBet
		FROM dbo.bettrans14 WITH (NOLOCK)
		WHERE winlostdate = @FromDate AND ip = @Ip
		GROUP BY
			custid,
			bettype,
			matchid,
			CASE
				WHEN bettype = 29 THEN refno
				ELSE 0
			END

		DELETE @UserTicket
		WHERE BetType > 19000
			OR BetType IN (903, 904, 913, 914)

		-- normal Soccer ticket
		UPDATE b
		SET b.SoccerBet = b.TotalBet
		FROM @UserTicket AS b
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.MatchId = m.matchid
		WHERE m.sporttype = 1 AND b.BetType <> 10

		-- outright Soccer ticket
		UPDATE b
		SET b.SoccerBet = b.TotalBet
		FROM @UserTicket AS b
			INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON o.orid = b.MatchId
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
		WHERE l.sporttype = 1 AND b.BetType = 10

		-- parlay Soccer ticket
		UPDATE b
		SET b.SoccerBet = b.TotalBet
		FROM @UserTicket AS b
		WHERE b.BetType = 29
			AND EXISTS (SELECT 1
						FROM dbo.bettransm14 AS bm WITH (NOLOCK)
							INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
						WHERE m.sporttype = 1 AND bm.refno = b.RefNo)
	END
	ELSE IF @FromDate < @BalanceUpDay
	BEGIN
		INSERT INTO @UserTicket
		SELECT
			custid,
			bettype,
			matchid,
			CASE
				WHEN bettype IN (9, 29) THEN refno
				ELSE 0
			END,
			0 AS SoccerBet,
			COUNT(1) AS TotalBet
		FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK)
		WHERE winlostdate = @FromDate AND ip = @Ip
		GROUP BY
			custid,
			bettype,
			matchid,
			CASE
				WHEN bettype IN (9, 29) THEN refno
				ELSE 0
			END

		DELETE @UserTicket
		WHERE BetType > 19000
			OR BetType IN (903, 904, 913, 914)

		-- normal Soccer ticket
		UPDATE b
		SET b.SoccerBet = b.TotalBet
		FROM @UserTicket AS b
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.MatchId = m.matchid
		WHERE m.sporttype = 1 AND b.BetType <> 10

		-- outright Soccer ticket
		UPDATE b
		SET b.SoccerBet = b.TotalBet
		FROM @UserTicket AS b
			INNER JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON o.orid = b.MatchId
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
		WHERE l.sporttype = 1 AND b.BetType = 10

		-- parlay Soccer ticket
		UPDATE b
		SET b.SoccerBet = b.TotalBet
		FROM @UserTicket AS b
		WHERE b.BetType IN (9, 29)
			AND EXISTS (SELECT 1
						FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
							INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
						WHERE m.sporttype = 1 AND bm.refno = b.RefNo)
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

	INSERT INTO @DeniedSite (SiteId, Site, SpecialGroup)
	SELECT
		s.siteid,
		s.site,
		s.SpecialGroup
	FROM dbo.Site AS s WITH (NOLOCK)
	WHERE NOT EXISTS (SELECT 1 FROM @DeniedSite WHERE SiteId = s.siteid)
		AND ((s.isLicensee = 0									-- Don't have Credit sites permission
				AND s.site <> 'cn88'
				AND ',' + @Permission + ',' NOT LIKE '%,1,%')
			OR (s.isLicensee = 1								-- Don't have Deposit sites permission
				AND s.site <> 'cn88'
				AND ',' + @Permission + ',' NOT LIKE '%,2,%')
			OR (s.site = 'cn88'									-- Don't have CN88 site permission
				AND ',' + @Permission + ',' NOT LIKE '%,3,%'))

	SELECT c.custid,
		c.username,
		SUM(u.SoccerBet) AS soccerBet,
		SUM(u.TotalBet)- SUM(u.SoccerBet) AS otherBet,
		SUM(u.TotalBet) AS totalBet
	FROM @UserTicket AS u
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON u.custid = c.custid
		INNER JOIN dbo.Customer AS a WITH (NOLOCK) ON c.recommend = a.custid
	WHERE a.site NOT IN (SELECT Site FROM @DeniedSite)
	GROUP BY c.custid,
		c.username
	ORDER BY c.username
END
GO



GRANT EXECUTE ON [dbo].[Acc_BetListbyIP_Username] TO [bodbAdminNet] AS [dbo]
GO
