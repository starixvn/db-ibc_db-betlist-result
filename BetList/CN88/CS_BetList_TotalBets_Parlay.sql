/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_BetList_TotalBets_Parlay]
	@CustId			INT,
	@RoleId			TINYINT,
	@Sport			SMALLINT	= 0,
	@StakeCondition TINYINT		= 1,
	@Stake			MONEY		= 0,
	@PossType		TINYINT		= 0
AS

/*
	Created: Kos@20190319
	Task: Bet List of CN88 Total Bets Parlay
	DB: DB042.bodb02

	Param's Explanation:
		- @RoleId: role ID
			- 1: Member
			- 2: Agent
			- 3: Master
			- 4: Super
		- @Sport:
			- 0: All
			- 1: Soccer only
			- 2: Non-Soccer only
			- 3: Mix Sports (include Soccer + Other Sports)
		- @StakeCondition:
			- 0: =
			- 1: >
			- 2: <
		- @PossType:
			- 0: Full Percentage
			- 1: Company %: Shown on SMA
			- 2: SMA %: Shown on SMA
			- 3: MA%: Shown on SMA, MA
			- 4: Agent%: Shown on SMA, MA, Agent
			- 5: SMA + MA + Agent%: Shown on SMA
			- 6: SMA + MA %: Shown on SMA
			- 7: MA + Agent %: Shown on SMA, MA

	Revisions:
		- 20190319@Kos: Create new [Redmine: 109230]
		
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @MemBetTicket TABLE (
		TransId			BIGINT,
		RefNo			BIGINT,
		CustId			INT,
		Username		NVARCHAR(50),
		BetType			SMALLINT,
		BetId			BIGINT,
		BetTeam			NVARCHAR(20),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		MOdds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		TPositionTaking	SMALLMONEY,
		PlayerDiscount	SMALLMONEY,
		ADiscount		SMALLMONEY,
		MDiscount		SMALLMONEY,
		SDiscount		SMALLMONEY,
		LiveHomeScore	SMALLINT,
		Ip				NVARCHAR(15),
		EventDate		DATETIME,
		BetCheck		NVARCHAR(50),
		ComStatus		NVARCHAR(20),
		Currency		NVARCHAR(50)
	)

	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10),
		TransDesc		VARCHAR(300)
	)

	IF @RoleId = 2		-- Agent
	BEGIN
		INSERT INTO @MemBetTicket
		SELECT
			CASE
				WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS TransId,
			b.refno,
			b.custid,
			b.username,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake,
			CASE
				WHEN b.status = 'running' THEN
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
			b.transdate,
			b.winlostdate,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.tpositiontaking,
			b.playerdiscount,
			b.discount AS ADiscount,
			b.adiscount AS MDiscount,
			b.sdiscount AS SDiscount,
			b.livehomescore,
			b.ip,
			b.winlostdate AS EventDate,
			ISNULL(b.betcheck, '') AS BetCheck,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
			b.currencyname AS Currency
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.recommend = @CustId
			AND b.statusID IN (0, 1)
			AND b.bettype IN (9, 29)
			AND b.matchid IN (9, 29)
			ANd (@Sport = 0 OR b.liveawayscore = @Sport)
			AND ((@StakeCondition = 0 AND b.Stake = @Stake)
				OR (@StakeCondition = 1 AND b.Stake > @Stake)
				OR (@StakeCondition = 2 AND b.Stake < @Stake))
	END
	ELSE IF @RoleId = 3		-- Master
	BEGIN
		INSERT INTO @MemBetTicket
		SELECT
			CASE
				WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS TransId,
			b.refno,
			b.custid,
			b.username,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake,
			CASE
				WHEN b.status = 'running' THEN
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
			b.transdate,
			b.winlostdate,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.tpositiontaking,
			b.playerdiscount,
			b.discount AS ADiscount,
			b.adiscount AS MDiscount,
			b.sdiscount AS SDiscount,
			b.livehomescore,
			b.ip,
			b.winlostdate AS EventDate,
			ISNULL(b.betcheck, '') AS BetCheck,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
			b.currencyname AS Currency
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.mrecommend = @CustId
			AND b.statusID IN (0, 1)
			AND b.bettype IN (9, 29)
			AND b.matchid IN (9, 29)
			ANd (@Sport = 0 OR b.liveawayscore = @Sport)
			AND ((@StakeCondition = 0 AND b.Stake = @Stake)
				OR (@StakeCondition = 1 AND b.Stake > @Stake)
				OR (@StakeCondition = 2 AND b.Stake < @Stake))
	END
	ELSE IF @RoleId = 4		-- Super
	BEGIN
		INSERT INTO @MemBetTicket
		SELECT
			CASE
				WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS TransId,
			b.refno,
			b.custid,
			b.username,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake,
			CASE
				WHEN b.status = 'running' THEN
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
			b.transdate,
			b.winlostdate,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.tpositiontaking,
			b.playerdiscount,
			b.discount AS ADiscount,
			b.adiscount AS MDiscount,
			b.sdiscount AS SDiscount,
			b.livehomescore,
			b.ip,
			b.winlostdate AS EventDate,
			ISNULL(b.betcheck, '') AS BetCheck,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
			b.currencyname AS Currency
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.srecommend = @CustId
			AND b.statusID IN (0, 1)
			AND b.bettype IN (9, 29)
			AND b.matchid IN (9, 29)
			ANd (@Sport = 0 OR b.liveawayscore = @Sport)
			AND ((@StakeCondition = 0 AND b.Stake = @Stake)
				OR (@StakeCondition = 1 AND b.Stake > @Stake)
				OR (@StakeCondition = 2 AND b.Stake < @Stake))
	END

	DECLARE @TicketPayout TABLE (
		RefNo			BIGINT,
		Serial			INT,
		SetStake		MONEY,
		Odds			SMALLMONEY,
		Payout			MONEY
	)

	;WITH
		_Source AS (
			SELECT
				bm.refno,
				bm.odds,
				CAST(b.Hdp2 AS TINYINT) AS SelectionCount,
				CAST(b.BetTeam AS INT) AS BitmapR,
				bm.stake AS SetStake,
				ROW_NUMBER() OVER (PARTITION BY bm.refno ORDER BY bm.matchid) AS RN
			FROM @MemBetTicket AS b
				INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.refno = b.refno
		),
		ParlayStake AS (
			SELECT
				refno,
				RN,
				SetStake
			FROM _Source)
	INSERT INTO @TicketPayout
	SELECT
		p.refno,
		rc.Serial,
		ps.SetStake,
		CAST(EXP(SUM(CAST(LOG(p.odds) AS DECIMAL(38, 20)))) AS MONEY) AS Odds,
		CAST(EXP(SUM(CAST(LOG(p.odds) AS DECIMAL(38, 20)))) AS MONEY) * ps.SetStake AS Payout
	FROM _source AS p
		INNER JOIN dbo.RefCombinationSet AS rcs WITH (NOLOCK) ON p.SelectionCount = rcs.N AND (p.bitmapR & rcs.bitmapR) > 0	-- Pick Set by BitmapR (get R)
		INNER JOIN dbo.RefCombination AS rc WITH (NOLOCK) ON rcs.N = rc.N AND rcs.R = rc.R AND p.RN = rc.Seq				-- Pick subticket details (R & seq)
		INNER JOIN ParlayStake AS ps ON ps.refno = p.refno AND ps.RN = rc.R
	GROUP BY
		p.refno,
		rc.Serial,
		ps.SetStake

	SELECT
		b.TransId,
		b.RefNo,
		b.CustId,
		b.Username,
		b.BetType,
		b.BetId,
		b.BetTeam,
		b.Hdp1,
		b.Hdp2,
		b.Odds,
		b.MOdds,
		CASE @PossType
			WHEN 0 THEN 1
			WHEN 1 THEN 1 - b.TPositionTaking
			WHEN 2 THEN b.SPositionTaking
			WHEN 3 THEN b.MPositionTaking
			WHEN 4 THEN b.APositionTaking
			WHEN 5 THEN b.SPositionTaking + b.MPositionTaking + b.APositionTaking
			WHEN 6 THEN b.SPositionTaking + b.MPositionTaking
			WHEN 7 THEN b.MPositionTaking + b.APositionTaking
		END * b.Stake AS Stake,
		CASE @PossType
			WHEN 0 THEN 1
			WHEN 1 THEN 1 - b.TPositionTaking
			WHEN 2 THEN b.SPositionTaking
			WHEN 3 THEN b.MPositionTaking
			WHEN 4 THEN b.APositionTaking
			WHEN 5 THEN b.SPositionTaking + b.MPositionTaking + b.APositionTaking
			WHEN 6 THEN b.SPositionTaking + b.MPositionTaking
			WHEN 7 THEN b.MPositionTaking + b.APositionTaking
		END * (p.Payout - b.Actual_Stake) AS Payout,
		b.Actual_Stake,
		b.Status,
		b.TransDate,
		b.WinLostDate,
		b.APositionTaking,
		b.MPositionTaking,
		b.SPositionTaking,
		b.TPositionTaking,
		b.PlayerDiscount,
		b.ADiscount,
		b.MDiscount,
		b.SDiscount,
		b.LiveHomeScore,
		b.Ip,
		b.EventDate,
		b.BetCheck,
		b.ComStatus,
		b.Currency,
		c.ugroup
	FROM @MemBetTicket AS b
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid
		INNER JOIN
			(SELECT
				RefNo,
				SUM(Payout) AS Payout
			FROM @TicketPayout
			GROUP BY RefNo ) AS p ON b.RefNo = p.RefNo
	ORDER BY TransId DESC

	SELECT * FROM @BettransDetail
	ORDER BY RefNo DESC
END
GO




GRANT EXECUTE ON [dbo].[CS_BetList_TotalBets_Parlay] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[CS_BetList_TotalBets_Parlay] TO [bodbDownlineNetView] AS [dbo]
GO
