/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Match3rdResultSel]
	@MatchId INT
AS

/*
	Created: 20210914@Kos
	Task: LAP/LRF Result Report - Get match 3rd result detail
	DB: DBEXT.bodb02

	Revisions:
		- 20210914@Kos: Support Bitcoin [Redmine: #160160]
		- 20241028@Kos: Support Betby Virtual Sports 6 [Redmine: #212446]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Detail TABLE (
		Match3rdId			INT,
		Custom1				NVARCHAR(50),
		Custom2				NVARCHAR(50),
		GameResult			VARCHAR(50),
		SettlementStatusID	TINYINT,
		ResourceId			VARCHAR(20)
	)

	IF EXISTS (SELECT 1 FROM dbo.Match3rd WITH (NOLOCK) WHERE match3rdid = @MatchId)
	BEGIN
		SELECT
			Match3rdId,
			matchcode,
			League3rdId,
			SportType,
			CASE
				WHEN SportType = 175 THEN EndTime
				ELSE StartTime
			END AS EventDate,
			BetStatus,
			EventStatus,
			HomeId,
			AwayId,
			hthomescore,
			htawayscore,
			finalhomescore,
			finalawayscore
		FROM dbo.Match3rd WITH (NOLOCK)
		WHERE Match3rdId = @MatchId

		INSERT INTO @Detail
		SELECT
			MatchID,
			Custom1,
			Custom2,
			GameResult,
			SettlementStatusID,
			ResourceId
		FROM dbo.ResultDetail3rd WITH (NOLOCK)
		WHERE MatchID = @MatchId AND SettlementStatusID > 0
	END
	ELSE IF EXISTS (SELECT 1 FROM dbo.Match3rd14 WITH (NOLOCK) WHERE match3rdid = @MatchId)
	BEGIN
		SELECT
			Match3rdId,
			matchcode,
			League3rdId,
			SportType,
			CASE
				WHEN SportType = 175 THEN EndTime
				ELSE StartTime
			END AS EventDate,
			BetStatus,
			EventStatus,
			HomeId,
			AwayId,
			hthomescore,
			htawayscore,
			finalhomescore,
			finalawayscore
		FROM dbo.Match3rd14 AS m WITH (NOLOCK)
		WHERE m.Match3rdId = @MatchId

		INSERT INTO @Detail
		SELECT
			MatchID,
			Custom1,
			Custom2,
			GameResult,
			SettlementStatusID,
			ResourceId
		FROM dbo.ResultDetail3rd14 WITH (NOLOCK)
		WHERE MatchID = @MatchId AND SettlementStatusID > 0
	END
	ELSE
	BEGIN
		SELECT
			Match3rdId,
			matchcode,
			League3rdId,
			SportType,
			CASE
				WHEN SportType = 175 THEN EndTime
				ELSE StartTime
			END AS EventDate,
			BetStatus,
			EventStatus,
			HomeId,
			AwayId,
			hthomescore,
			htawayscore,
			finalhomescore,
			finalawayscore
		FROM DBARC.bodb_Archive.dbo.match3rd_bk WITH (NOLOCK)
		WHERE Match3rdId = @MatchId

		INSERT INTO @Detail
		SELECT
			MatchID,
			Custom1,
			Custom2,
			GameResult,
			SettlementStatusID,
			ResourceId
		FROM DBARC.bodb_Archive.dbo.ResultDetail3rd_bk WITH (NOLOCK)
		WHERE MatchID = @MatchId AND SettlementStatusID > 0
	END

	SELECT * FROM @Detail
END
GO
