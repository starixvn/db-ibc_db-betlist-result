/*<info serverAlias="DBOST-bodb_ost" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Ost_LastBets_Other]
	@CustId			INT,
	@TransId		BIGINT	= 0,
	@LimitRowCount	INT		= 20
AS

/*
	Created: Kos@20200109
	Task: Last Bets - Other bet types
	DB: DBOST.bodb_ost
	Revision:
		- 20200109@Kos: Created [Redmine: #121898]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = bodb02.dbo.f_CheckSPVersion(@@PROCID)

	; WITH __bettypeList AS (
		SELECT BetType
		FROM bodb02.dbo.SportBettypeMatrix WITH (NOLOCK)
		WHERE ProductID = 1 AND IsTest IN (0, @IsTest)
		GROUP BY BetType
	)
	SELECT TOP(@LimitRowCount)
		b.custid,
		b.matchid,
		b.Username,
		b.bettype,
		b.transid,
		b.refno,
		b.transdate,
		b.betid,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator,
		b.hdp1,
		b.hdp2,
		b.odds,
		b.stake,
		b.actual_stake,
		CASE
			WHEN b.bettype NOT IN (9, 29) AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			WHEN b.bettype IN (9, 29) AND b.status = 'running' THEN
				CASE
					WHEN EXISTS (SELECT 1 FROM bodb02.dbo.bettransm AS bm WITH (NOLOCK)
								WHERE bm.custid = b.custid
									AND bm.refno = b.refno
									AND (bm.status = 'waiting'
										OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
						THEN 'Waiting'
					ELSE b.status
				END
			ELSE b.status
		END AS status,
		b.betteam,
		b.ip,
		b.oddstype,
		ISNULL(b.betcheck, '') AS Betcheck,
		ISNULL(b.transdesc, '') AS transdesc,
		0 AS OddsSpread,
		ISNULL(b.ExtraInfo, '') AS ExtraInfo
	FROM dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.recommend = @CustId
		AND b.statusID IN (0,1)
		AND b.transid > @TransId
		AND b.bettype NOT BETWEEN 801 AND 806
		AND b.bettype NOT IN (1, 3, 7, 8)
		AND EXISTS (SELECT TOP 1 1 FROM __bettypeList AS s WHERE b.bettype = s.BetType)
	ORDER BY b.transid DESC
END
GO


GRANT EXECUTE ON [dbo].[Ost_LastBets_Other] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Ost_LastBets_Other] TO [bodbDownlineNetView]
GO
