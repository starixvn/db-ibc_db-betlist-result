
ALTER PROCEDURE [dbo].[Age_BetList_SelAllByDateHR_Ag]
	@CustId		INT			= NULL,		-- AgentID
	@BetType	INT,
	@MatchId	INT,
	@Language	VARCHAR(2)	= 'E'
AS

/*
	Created:
	Task: get Horse Racing tickets for Agent level
	DB: DBAGE.bodb02
	Original 
	Revisions:
		- 20090406@HanhVu: Remove refno
		- 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost 
		- 20090505@HiepVo: Change formula of commission
		- 20090529@HiepVo:  Get more data from bettransm for HR
		- 20090618@AnhPham: Remove 'Customer' table
		- 20091024@[MinhNguyen]: get modds, finalodds.
		- 20091028@AnhPham: remove unnecessary values concern to winlost, commission, PT, discount of upline
		- 20110307@Lukas: get more sporttype (152, 153)
		- 20110602@Amy: add more condition to get ticket details for WIN/PLACE (33)
		- 20120313@Lukas: Modify winlostdate condition to get Aust racing tickets ( cross-date meetings)
		- 20120927@Sophia: Get comstatus
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Horse Racing only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (2, 0, 0, 2, '', '', @IsTest)

	DECLARE @FromDate	DATETIME,
		@ToDate			DATETIME

	SELECT @ToDate = CONVERT(DATETIME,CONVERT(NVARCHAR(20), GETDATE(), 101))

	SELECT @FromDate = DATEADD(dd, -1, @ToDate),
		@Todate = DATEADD(dd, 1, @Todate)
 
	SELECT
		b.UserName,
		l.sporttype,
		b.bettype,
		b.transid,
		m.matchcode,
		b.matchid,
		m.GroupMatch AS Race,
		m.teamID AS homeID,
		0 AS awayID,
		b.hdp1,
		b.hdp2,
		modds,
		b.odds,
		b.status,
		b.stake,
		(winlost-actual_stake)  winlost,
		b.awinlost,
		0 AS mwinlost,
		0 AS swinlost,
		b.playercomm,
		(b.comm - b.playercomm) AS comm,
		0 AS acomm,
		0 AS scomm,
		b.transdate,
		b.winlostdate,
		'' AS Betteam,
		b.apositiontaking,
		0 AS mpositiontaking,
		0 AS spositiontaking,
		b.discount AS adiscount,
		0 AS mdiscount,
		0 AS sdiscount,
		m.leagueID,
		0 AS liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.ip,
		'' betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
		INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE b.recommend = @CustId
		AND m.eventdate BETWEEN @FromDate AND @ToDate
		AND b.matchid = @MatchId
		AND b.bettype = @BetType

	-- Get sub tickets
	IF @Bettype IN (33, 43)
	BEGIN
		SELECT
			bm.refno,
			bm.finalodds,
			bm.odds,
			bm.status,
			bm.apositiontaking,
			0 AS mpositiontaking,
			0 AS spositiontaking,
			bm.bettype
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON bm.refno = b.transid
			INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
		WHERE b.bettype = @BetType
			AND b.matchid = @MatchId
			AND b.recommend = @CustId
	END
END



GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelAllByDateHR_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelAllByDateHR_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelAllByDateHR_Ag] TO [vnteam]
