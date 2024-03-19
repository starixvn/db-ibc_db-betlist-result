/*<info serverAlias="DBOST-bodb_ost" executers="bodbDownlineNet, wsv_alp,bodbDownlineNetView, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Ost_LastBets_HDP]
	@CustId			INT,
	@TransId		BIGINT	= 0,
	@LimitRowCount	INT		= 20
AS

/*
	Created: Kos@20200109
	Task: Last Bets - Handicap bet types
	DB: DBOST.bodb_ost
	Revision:
		- 20200109@Kos: Created [Redmine: #121898]
*/

BEGIN
	SET NOCOUNT ON

	SELECT TOP(@LimitRowCount)
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
		CASE
			WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			ELSE b.status
		END AS Status,
		b.betteam,
		b.ip,
		b.oddstype,
		ISNULL(b.oddsspread, 0) AS OddsSpread,
		ISNULL(b.ExtraInfo, '') AS ExtraInfo
	FROM dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.recommend = @CustId
		AND b.statusID IN (0, 1)
		AND b.transid > @TransId
		AND b.bettype IN (1, 7)
	ORDER BY b.transid DESC
END
GO
