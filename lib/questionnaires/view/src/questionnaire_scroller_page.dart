import 'package:fhir/r4.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../logging/logging.dart';
import '../../../resource_provider/resource_provider.dart';
import '../../questionnaires.dart';

/// Fills a [Questionnaire] through a vertically scrolling input form.
///
/// Takes the [QuestionnaireItemFiller]s as provided by the [QuestionnaireFiller]
/// and presents them as a scrolling [ListView].
///
/// A set of mandatory and optional FHIR resources need to be provided through
/// the [fhirResourceProvider]:
/// * (mandatory) [questionnaireResourceUri] - the [Questionnaire]
/// * (mandatory) [subjectResourceUri] - the [Patient]
/// * (optional) [questionnaireResponseResourceUri] - the [QuestionnaireResponse].
/// Will be used to prefill the filler, if present.
class QuestionnaireScrollerPage extends StatefulWidget {
  final Locale? locale;
  final Widget? floatingActionButton;
  final List<Widget>? persistentFooterButtons;
  final List<Widget>? frontMatter;
  final List<Widget>? backMatter;
  final FhirResourceProvider fhirResourceProvider;
  final List<Aggregator<dynamic>>? aggregators;
  final void Function(BuildContext context, Uri url)? onLinkTap;

  const QuestionnaireScrollerPage(
      {this.locale,
      required this.fhirResourceProvider,
      this.floatingActionButton,
      this.persistentFooterButtons,
      this.frontMatter,
      this.backMatter = const [
        SizedBox(
          height: 80,
        )
      ],
      this.aggregators,
      this.onLinkTap,
      Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _QuestionnaireScrollerState();
}

class _QuestionnaireScrollerState extends State<QuestionnaireScrollerPage> {
  QuestionnaireModel? _questionnaireModel;
  final ItemScrollController _listScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // What is the desired position to scroll to?
  int _focusIndex = -1;

  bool _isLoaded = false;

  // Has the scroller already been scrolled once to the desired position?
  bool _isPositioned = false;

  // Has the focus already been placed?
  bool _isFocussed = false;

  static final _logger = Logger(_QuestionnaireScrollerState);

  _QuestionnaireScrollerState() : super();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void scrollToMarker(QuestionnaireMarker marker) {
    if (_questionnaireModel == null) {
      _logger.info(
          'Trying to scroll before QuestionnaireModel is loaded. Ignoring.');
      return;
    }

    final index =
        _questionnaireModel!.indexOf((qim) => qim.linkId == marker.linkId);

    if (index == -1) {
      _logger.warn('Marker with invalid linkId: ${marker.linkId}');
      return;
    }

    scrollTo(index!);
  }

  void scrollTo(int index) {
    if (!_listScrollController.isAttached) {
      _logger.info(
          'Trying to scroll before ListScrollController is attached. Ignoring.');
      return;
    }

    final milliseconds = (index < 10) ? 1000 : 1000 + (index - 10) * 100;
    _listScrollController.scrollTo(
        index: index,
        duration: Duration(milliseconds: milliseconds),
        curve: Curves.easeInOutCubic,
        alignment:
            0.3); // Scroll the item's top-edge into the top 30% of the screen.
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale ?? Localizations.localeOf(context);

    return QuestionnaireFiller(
      fhirResourceProvider: widget.fhirResourceProvider,
      locale: locale,
      builder: (BuildContext context) {
        final questionnaireFiller = QuestionnaireFiller.of(context);

        final mainMatterLength =
            questionnaireFiller.questionnaireItemModels.length;
        final frontMatterLength = widget.frontMatter?.length ?? 0;
        final backMatterLength = widget.backMatter?.length ?? 0;
        final totalLength =
            frontMatterLength + mainMatterLength + backMatterLength;

        final questionnaire =
            questionnaireFiller.questionnaireModel.questionnaire;

        _logger.trace(
            'Scroll position: ${_itemPositionsListener.itemPositions.value}');

        return Localizations.override(
            context: context,
            locale: locale,
            child: Scaffold(
              appBar: AppBar(
                leading: Builder(
                  builder: (BuildContext context) {
                    return IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
                title: Row(children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 200,
                    child: Text(
                      questionnaire.title ?? 'Survey',
                      maxLines: 2,
                      softWrap: true,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    onPressed: () {
                      QuestionnaireInformationDialog.showQuestionnaireInfo(
                          context, locale, questionnaire, (context) {
                        setState(() {
                          Navigator.pop(context);
                        });
                      });
                    },
                  ),
                ]),
              ),
              endDrawer: const NarrativeDrawer(),
              floatingActionButton: widget.floatingActionButton,
              persistentFooterButtons: widget.persistentFooterButtons,
              body: SafeArea(
                child: ScrollablePositionedList.builder(
                    itemScrollController: _listScrollController,
                    itemPositionsListener: _itemPositionsListener,
                    itemCount: totalLength,
                    padding: const EdgeInsets.all(8),
                    // TODO: This used to work but seems broken now?
                    minCacheExtent: 200, // Allow tabbing to prev/next items
                    itemBuilder: (BuildContext context, int i) {
                      final frontMatterIndex = (i < frontMatterLength) ? i : -1;
                      final mainMatterIndex = (i >= frontMatterLength &&
                              i < (frontMatterLength + mainMatterLength))
                          ? (i - frontMatterLength)
                          : -1;
                      final backMatterIndex =
                          (i >= (frontMatterLength + mainMatterLength) &&
                                  i < totalLength)
                              ? (i - (frontMatterLength + mainMatterLength))
                              : -1;
                      if (mainMatterIndex != -1) {
                        final qf = QuestionnaireFiller.of(context);
                        final qif = qf.itemFillerAt(mainMatterIndex);
                        if (!_isFocussed && _focusIndex == mainMatterIndex) {
                          WidgetsBinding.instance
                              ?.addPostFrameCallback((timeStamp) {
                            qf.requestFocus(mainMatterIndex);
                          });

                          _isFocussed = true;
                        }
                        return qif;
                      } else if (backMatterIndex != -1) {
                        return widget.backMatter![backMatterIndex];
                      } else if (frontMatterIndex != -1) {
                        return widget.frontMatter![frontMatterIndex];
                      } else {
                        throw StateError('ListView index out of bounds: $i');
                      }
                    }),
              ),
            ));
      },
      aggregators: widget.aggregators,
      onDataAvailable: (questionnaireModel) {
        if (_isPositioned) {
          return;
        }

        // Upon initial load: Locate the first unanswered or invalid question
        if (!_isLoaded) {
          _isLoaded = true;

          _questionnaireModel = questionnaireModel;

          // Listen for new markers and then scroll to the first one.
          questionnaireModel.markers.addListener(() {
            final markers = questionnaireModel.markers.value;
            if (markers != null) {
              scrollToMarker(markers.first);
            }
          });

          _focusIndex = questionnaireModel
              .indexOf((qim) => qim.isUnanswered || qim.isInvalid)!;

          if (_focusIndex == -1) {
            // When all questions are answered then focus on the first field that can be filled by a human.
            _focusIndex = questionnaireModel.indexOf((qim) => !qim.isReadOnly)!;
          }
        }

        if (_focusIndex <= 0) {
          return;
        }

        _logger.debug(
            'Focussing item# $_focusIndex - ${questionnaireModel.itemModelAt(_focusIndex)}');

        _itemPositionsListener.itemPositions
            .addListener(_initialPositionListener);
      },
      onLinkTap: widget.onLinkTap,
    );
  }

  void _initialPositionListener() {
    // This is one-time only
    _itemPositionsListener.itemPositions
        .removeListener(_initialPositionListener);

    _logger.trace(
        'Scroll positions changed to: ${_itemPositionsListener.itemPositions.value}');

    _isPositioned = true;

    // Item could be visible, but in an undesirable position, e.g.
    // at the bottom of the display. Make sure it is in the top third of screen.
    final isItemVisible = _itemPositionsListener.itemPositions.value.any(
        (element) =>
            element.index == _focusIndex && element.itemLeadingEdge < 0.35);

    _logger.debug('Item $_focusIndex already visible: $isItemVisible');

    if (isItemVisible) {
      return;
    }

    // After the model data is loaded, wait until the end of the current frame,
    // and then scroll to the desired location.
    //
    // Rationale: Before the data is loaded the QuestionnaireFiller is still
    // showing progress indicator and no scrolling is possible.
    // On the first frame after data is loaded the _listScrollController is not
    // properly attached yet and will throw an exception.
    WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
      scrollTo(_focusIndex);
    });
  }
}
